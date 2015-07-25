require "helpers"
local pp = require("purepack")
require "conf"

local function name(metric_,step_,period_)
  return string.format("%s;%s:%s",metric_,
                       secs_to_time_unit(step_),
                       secs_to_time_unit(period_))
end

local nop = function() end
local return_0 = function() return 0 end

local NOP_SEQUENCE = {
  slots = function() return {} end,
  name = function() return "" end,
  metric = return_0,
  step = return_0,
  period = return_0,
  slot = nop,
  slot_index = return_0,
  update = nop,
  update_batch = nop,
  latest = nop,
  latest_timestamp = return_0,
  reset = nop,
  serialize = nop,
}

function sequence(db_,name_)
  local _metric,_step,_period,_name,_seq_storage

  local function at(idx_,offset_,a_,b_,c_)
    -- a nil offset_ is translated to reading/writing the entire cell (3 items)
    if not a_ then
      return _seq_storage.get_slot(idx_,offset_)
    end
    _seq_storage.set_slot(idx_,offset_,a_,b_,c_)
  end

  local function get_timestamp(idx_)
    return at(idx_,0)
  end

  local function latest(latest_idx_)
    local pos = math.floor(_period/_step)
    if not latest_idx_ then
      return at(pos,0)
    end
    at(pos,0,latest_idx_)
  end

  local function indices(sorted_)
    if not sorted_ then
      return coroutine.wrap(
        function()
          for i=1,(_period/_step) do
            coroutine.yield(i-1)
          end
      end)
    end
    local array = {}
    for i=1,(_period/_step) do
      array[i] = {i-1,get_timestamp(i-1)}
    end
    table.sort(array, function(u,v) return u[2]<v[2] end)
    return coroutine.wrap(
      function()
        for _,s in ipairs(array) do
          coroutine.yield(s[1])
        end
    end)
  end


  local function find_latest()
    local latest = 0
    local latest_idx = 0
    for s in indices() do
      local timestamp,hits,sum = at(s)
      if sum>latest then
        latest = sum
        latest_idx = s
      end
    end
    return latest_idx,latest
  end

  local function fix_timestamp(latest_idx)
    local new_latest_idx,new_latest = find_latest()
    if new_latest>0 then
      logw("latest_timestamp - fixing",name_,latest_idx,new_latest_idx,new_latest)
      latest(new_latest_idx)
    end
    return new_latest
  end

  local function latest_timestamp()
    local latest_idx = latest()
    if get_timestamp(latest_idx)>0 then
      return get_timestamp(latest_idx)
    end

    -- fix_timestamp(latest_idx) -- enable to fix the latest timestamp
    if latest_idx>0 then
        logw("latest_timestamp is 0",_name,latest_idx)
    end
    return get_timestamp(latest_idx)
  end

  local function reset()
    _seq_storage.reset()
    _seq_storage.save()
  end

  _name = name_

  _metric,_step,_period = split_name(name_)
  if not (_metric and _step and _period ) then
    loge("failed creating sequence",name_)
    --loge(debug.traceback())
    return NOP_SEQUENCE
  end

  _seq_storage = db_.sequence_storage(name_,_period/_step)

  local function update(timestamp_,hits_,sum_,type_)
    local idx,adjusted_timestamp = calculate_idx(timestamp_,_step,_period)
    local timestamp,hits,sum = at(idx)

    -- we need to check whether we should update the current slot
    -- or if are way ahead of the previous time the slot was updated
    -- over-write its value. We rely on the invariant that timestamp should be >= adjusted_timestamp
    if adjusted_timestamp<timestamp then
      return
    end


    if (not type_) then
      if adjusted_timestamp==timestamp and hits>0 then
        -- no need to worry about the latest here, as we have the same (adjusted) timestamp
        hits,sum = hits+(hits_ or 1), sum+sum_
      else
        hits,sum = hits_ or 1,sum_
      end
    elseif type_=='=' then
      hits,sum = hits_ or 1,sum_
    elseif type_=='^' then
      hits,sum = hits_ or 1,math.max(sum_,sum)
    end

    at(idx,nil,adjusted_timestamp,hits,sum)
    local lt = latest_timestamp()
    if adjusted_timestamp>lt then
      latest(idx)
    end

    _seq_storage.save(_name)
    return adjusted_timestamp,sum
  end

  local function update_batch(slots_,ts,ht,sm)
    -- slots is a flat array of arrays.
    -- it is kind of ugly that we need to pass the indices to the various cells in each slot, but an inconsistency
    -- in the order that is too fundemental to change, forces us to.
    local j = 1
    local match = string.match
    while j<#slots_ do
      local timestamp,hits,sum,typ = legit_input_line("",tonumber(slots_[j+sm]),tonumber(slots_[j+ts]),tonumber(slots_[j+ht]))
      j = j + 3
      update(timestamp,hits,sum,"=")
    end

    _seq_storage.save(_name)
    return j-1
  end


  local function reset_to_timestamp(timestamp_)
    local _,adjusted_timestamp = calculate_idx(timestamp_,_step,_period)
    local affected = false
    for s in indices() do
      local ts = get_timestamp(s)
      if ts>0 and ts<=adjusted_timestamp then
        update(ts,0,0,'=')
        affected = true
      end
    end
    return affected
  end


  local function serialize(opts_,metric_cb_,slot_cb_)
    local date = os.date
    local readable = opts_.readable
    local average = opts_.stat=="average"
    local factor = opts_.factor and tonumber(opts_.factor) or nil
    local format = string.format

    local function serialize_slot(idx_,skip_empty_,slot_cb_)
      local timestamp,hits,sum = at(idx_)
      if not skip_empty_ or sum~=0 or hits~=0 or timestamp~=0 then
        local value = sum
        if average then
          value = average and (sum/hits)
        elseif factor then
          value = sum/factor
        end
        if readable then
          timestamp = format('"%s"',date("%y%m%d:%H%M%S",timestamp))
        end
        slot_cb_(value,hits,timestamp)
      end
    end

    opts_ = opts_ or {}
    metric_cb_(_metric,_step,_period)

    local now = time_now()
    local latest_ts = latest_timestamp()
    local min_timestamp = (opts_.filter=="latest" and latest_ts-_period) or
      (opts_.filter=="now" and now-_period) or nil

    if opts_.all_slots then
      if not opts_.dont_cache then
        _seq_storage.cache(name_) -- this is a hint that the sequence can be cached
      end
      for s in indices(opts_.sorted) do
        if not min_timestamp or min_timestamp<get_timestamp(s) then
          serialize_slot(s,opts_.skip_empty,slot_cb_)
        end
      end
      return
    end

    if opts_.timestamps then
      for _,t in ipairs(opts_.timestamps) do
        if t=="*" then
          for s in indices(opts_.sorted) do
            serialize_slot(s,true,slot_cb_)
          end
        else
          local ts = to_timestamp(t,now,latest_ts)
          if ts then
            if type(ts)=="number" then
              ts = {ts,ts+_step-1}
            end
            local visited = {}
            for t = ts[1],ts[2],(ts[1]<ts[2] and _step or -_step) do
              -- the range can be very large, like 0..1100000 and we'll be recycling through the same slots
              -- over and over. We therefore cache the calculated indices and skip those we've seen.
              local idx,_ = calculate_idx(t,_step,_period)
              if not visited[idx] then
                local its = get_timestamp(idx)
                if t-its<_period and (not min_timestamp or min_timestamp<its) then
                  serialize_slot(idx,true,slot_cb_)
                end
                visited[idx] = true
              end
            end
          end
        end
      end
    end
  end

  local function slot(idx_)
    local ts,h,s = at(idx_)
    return { _timestamp = ts, _hits = h, _sum = s }
  end

  local function to_slots_array()
    local slots = {}
    local insert = table.insert
    for i=0,_period/_step do
      local a,b,c = at(i)
      insert(slots,a)
      insert(slots,b)
      insert(slots,c)
    end
    return slots
  end

  return {
    slots = function() return to_slots_array() end,
    name = function() return _name end,
    metric = function() return _metric end,
    step = function() return _step end,
    period = function() return _period end,
    slot = slot,
    slot_index = function(timestamp_) return calculate_idx(timestamp_,_step,_period) end,
    update = update,
    update_batch = update_batch,
    latest = latest,
    latest_timestamp = latest_timestamp,
    reset_to_timestamp = reset_to_timestamp,
    reset = reset,
    serialize = serialize,
  }
end


local function sequences_for_prefix(db_,prefix_,retention_pair_,level_)
  return coroutine.wrap(
    function()
      local find = string.find
      local yield = coroutine.yield
      prefix_ = (prefix_=="*" and "") or prefix_
      for name in db_.matching_keys(prefix_,level_) do
        if not retention_pair_ or find(name,retention_pair_,1,true) then
          yield(sequence(db_,name))
        end
      end
  end)
end

function immediate_metrics(db_,name_,level_)
  -- if the name_ has th retention pair in it, we just return it
  -- otherwise we provide all the retention pairs
  return coroutine.wrap(
    function()
      for name in db_.matching_keys(name_,0) do
        coroutine.yield(sequence(db_,name))
      end
  end)
end


local function wrap_json(stream_)
  local str = stream_.get_string()
  if #str==0 then return nil end
  return string.format("{\"version\": %d,\n\"data\": %s\n}",
                       CURRENT_VERSION,
                       #str>0 and str or '""')
end


local function each_metric(db_,metrics_,retention_pair_,callback_)
  for m in split_helper(metrics_,"/") do
    for seq in sequences_for_prefix(db_,m,retention_pair_) do
      callback_(seq)
    end
  end
end

function mule(db_)
  local _factories = {}
  local _sorted_factories
  local _alerts = {}
  local _anomalies = {} -- these do not persist as they can be recalulated
  local _db = db_
  local _updated_sequences = {}
  local _hints = {}
  local _flush_cache_logger = every_nth_call(10,
                                             function()
                                               local a = table_size(_updated_sequences)
                                               if a>0 then
                                                 logi("mulelib flush_cache",a)
                                               end
  end)
  local update_sequence = nil -- foreward declaration

  local function increment(metric_,value_,hits_)
    local now = os.time()
    update_sequence(metric_..";5m:3d",value_ or  1,now,hits_ or 1,now)
  end

  db_.set_increment(increment)

  local function uniq_factories()
    local factories = _factories
    _factories = {}
    for fm,rps in pairs(factories) do
      _factories[fm] = uniq_pairs(rps)
    end
    _sorted_factories = keys(_factories)
    table.sort(_sorted_factories)
  end

  local function add_factory(metric_,retentions_)
    metric_ = string.match(metric_,"^(.-)%.*$")
    for _,rp in ipairs(retentions_) do
      local step,period = parse_time_pair(rp)
      if step and period then
        if step>period then
          loge("step greater than period",rp,step,period)
          error("step greater than period")
          return nil
        end
        _factories[metric_] = _factories[metric_] or {}
        table.insert(_factories[metric_],{step,period})
      end
    end

    -- now we make sure the factories are unique
    uniq_factories()
    return true
  end


  local function get_sequences(metric_)
    return coroutine.wrap(
      function()
        local metric_rps = {}
        local idx = 1
        while idx<=#_sorted_factories and _sorted_factories[idx]<=metric_ do
          if is_prefix(metric_,_sorted_factories[idx]) then
            local fm = _sorted_factories[idx]
            table.insert(metric_rps,{fm,_factories[fm]})
          end
          idx = idx + 1
        end

        local seqs = {}
        for m in metric_hierarchy(metric_) do
          for _,frp in ipairs(metric_rps) do
            if is_prefix(m,frp[1]) then
              for _,rp in ipairs(frp[2]) do
                seqs[name(m,rp[1],rp[2])] = m
              end
            end
          end
        end
        for n,m in pairs(seqs) do
          coroutine.yield(n,m)
        end
    end)
  end

  local function update_rank(rank_timestamp_,rank_,timestamp_,value_,name_,step_)
    local ts,rk,same_ts = update_rank_helper(rank_timestamp_,rank_,timestamp_,value_,step_)
    return ts,rk
  end


  local function alert_check_stale(seq_,timestamp_)
    local alert = _alerts[seq_.name()]
    if not alert then
      return nil
    end

    if alert._stale then
      if seq_.latest_timestamp()+alert._stale<timestamp_ then
        alert._state = "stale"
        return true
      end
      alert._state = nil
    end
    return false
  end

  local function alert_check(sequence_,timestamp_)
    local name = sequence_.name()
    local alert = _alerts[name]
    if not alert then
      return nil
    end

    if alert_check_stale(sequence_,timestamp_) then
      return alert
    end

    local average_sum = 0
    local step = sequence_.step()
    local period = sequence_.period()
    local start = timestamp_-alert._period
    for ts = start,timestamp_,step do
      local idx,normalized_ts = calculate_idx(ts,step,period)
      local slot = sequence_.slot(idx)
      --      logd("alert_check",name,ts,start,slot._timestamp,slot._sum,step,average_sum)
      if normalized_ts==slot._timestamp and slot._hits>0 then
        if ts==start then
          -- we need to take only the proportionate part of the first slot
          average_sum = slot._sum*(slot._timestamp+step-start)/step
        else
          average_sum = average_sum + slot._sum
        end
      end
    end

    alert._sum = average_sum
    if alert._critical_low and alert._warning_low and alert._critical_high and alert._warning_high then
      alert._state = (alert._critical_low~=-1 and average_sum<alert._critical_low and "CRITICAL LOW") or
        (alert._warning_low~=-1 and average_sum<alert._warning_low and "WARNING LOW") or
        (alert._critical_high~=-1 and average_sum>alert._critical_high and "CRITICAL HIGH") or
        (alert._warning_high~=-1 and average_sum>alert._warning_high and "WARNING HIGH") or
        "NORMAL"
    else
      alert._state = "NORMAL"
    end
    return alert
  end

  local function flush_cache_of_sequence(name_,sparse_)
    sparse_ = sparse_  or _updated_sequences[name_]
    if not sparse_ then return nil end

    local seq = sequence(_db,name_)
    local now = time_now()
    increment("mule.mulelib.flush_cache_of_sequence")
    for j,sl in ipairs(sparse_.slots()) do
      local adjusted_timestamp,sum = seq.update(sl._timestamp,sl._hits or 1,sl._sum,sl._type)
      if adjusted_timestamp and sum then
        _hints[name_] = _hints[name_] or {}
        if not _hints[name_]._rank_ts then
          _hints[name_]._rank = 0
          _hints[name_]._rank_ts = 0
        end
        _hints[name_]._rank_ts,_hints[name_]._rank = update_rank(
          _hints[name_]._rank_ts,_hints[name_]._rank,
          adjusted_timestamp,sum,name_,seq.step())
      end
      alert_check(seq,now)
    end
    _updated_sequences[name_] = nil
  end

  local function flush_cache(max_,step_)
    _flush_cache_logger()

    -- we now update the real sequences
    local num_processed = 0
    local size,st,en = random_table_region(_updated_sequences,max_)
    if size==0 then return false end
    increment("mule.mulelib.flush_cache")
    for n,s in iterate_table(_updated_sequences,st,en) do
      flush_cache_of_sequence(n,s)
      num_processed = num_processed + 1
    end
    if num_processed==0 then return false end
    -- returns true if there are more items to process
    return _updated_sequences and next(_updated_sequences)~=nil
  end



  local function gc(resource_,options_)
    local garbage = {}
    local str = strout("","\n")
    local format = string.format
    local col = collectionout(str,"[","]")
    local timestamp = tonumber(options_.timestamp)

    if not timestamp then
      str.write('{"error": "timestamp must be provided"}');
    else
      col.head()

      each_metric(_db,resource_,nil,
                  function(seq)
                    if seq.latest_timestamp()<timestamp then
                      col.elem(format("\"%s\": %d",seq.name(),seq.latest_timestamp()))
                      garbage[#garbage+1] = seq.name()
                    end
      end)
      col.tail()

      if options_.force then
        for _,name in ipairs(garbage) do
          _db.out(name)
        end
      end
    end

    return wrap_json(str)
  end


  local function dump(resource_,options_)
    local str = options_.to_str and strout("") or stdout("")
    local serialize_opts = {all_slots=true,skip_empty=true,dont_cache=true} -- caching kills us when dumping large DBs

    each_metric(_db,resource_,nil,
                function(seq)
                  flush_cache_of_sequence(seq)
                  seq.serialize(serialize_opts,
                                function()
                                  str.write(seq.name())
                                end,
                                function(sum,hits,timestamp)
                                  str.write(" ",sum," ",hits," ",timestamp)
                  end)
                  str.write("\n")
    end)
    return str
  end

  local function output_anomalies(names_)
    local str = strout("","\n")
    local format = string.format
    local col = collectionout(str,"{","}")
    local now = time_now()
    col.head()

    for k,v in pairs(_anomalies) do
      if not names_ or names_[k] then
        col.elem(format("\"%s\": [%s]",k,table.concat(v,",")))
      end
    end
    col.tail()
    return str
  end

  local function output_alerts(names_,all_anomalies_)
    local str = strout("","\n")
    local format = string.format
    local col = collectionout(str,"{","}")
    local now = time_now()
    local ans = not all_anomalies_ and {} or nil
    col.head()

    for _,n in ipairs(names_) do
      local seq = sequence(db_,n)
      local a,msg = alert_check(seq,now)
      if a and a._critical_low and a._warning_low and a._warning_high and a._critical_high and a._period then
        col.elem(format("\"%s\": [%d,%d,%d,%d,%d,%s,%d,\"%s\",%d,\"%s\"]",
                        n,a._critical_low,a._warning_low,a._warning_high,a._critical_high,
                        a._period,a._stale or "-1",a._sum,a._state,now,msg or ""))
      end
      if not all_anomalies_ then
        ans[n] = true
      end
    end
    col.elem(format("\"anomalies\": %s",output_anomalies(ans).get_string()))
    col.tail()
    return str
  end

  local function graph(resource_,options_)
    local str = strout("")
    options_ = options_ or {}
    local timestamps = options_.timestamp and split(options_.timestamp,',') or nil
    local format = string.format
    local col = collectionout(str,"{","}")
    local opts = { all_slots=not timestamps,
                   filter=options_.filter,
                   readable=is_true(options_.readable),
                   timestamps=timestamps,
                   sorted=is_true(options_.sorted),
                   stat=options_.stat,
                   factor=options_.factor,
                   skip_empty=true}
    local sequences_generator = immediate_metrics
    local alerts = is_true(options_.alerts)
    local names = {}
    local level = options_.level and tonumber(options_.level)
    local insert = table.insert
    local now = time_now()
    local find = string.find
    local in_memory = options_.in_memory and {}
    local count = 0

    col.head()
    for m in split_helper(resource_,"/") do
      if level then
        local ranked_children = {}
        local metric,rp = string.match(m,"^([^;]+)(;%w+:%w+)$")
        metric = metric or m
        for seq in sequences_for_prefix(db_,metric,rp,level) do
          local name = seq.name()
          local name_level = count_dots(name)
          -- we call update_rank to get adjusted ranks (in case the previous update was
          -- long ago). This is a readonly operation
          local hint = _hints[seq.name()] or {}
          local _,seq_rank = update_rank(
            hint._rank_ts or 0 ,hint._rank or 0,
            normalize_timestamp(now,seq.step(),seq.period()),0,seq.name(),seq.step())
          insert(ranked_children,{seq,seq_rank,name_level})
        end
        table.sort(ranked_children,function(a,b) return a[3]<b[3] or (a[3]==b[3] and a[2]>b[2]) end)
        sequences_generator = function()
          return coroutine.wrap(
            function()
              for i=1,(math.min(#ranked_children,options_.count or DEFAULT_COUNT)) do
                coroutine.yield(ranked_children[i][1])
              end
          end)
        end
      end

      for seq in sequences_generator(db_,m,level) do
        flush_cache_of_sequence(seq)
        count = count+1
        if in_memory then
          local current = {}
          seq.serialize(
            opts,
            function()
              in_memory[seq.name()] = current
            end,
            function(sum,hits,timestamp)
              insert(current,{sum,hits,timestamp})
          end)
        else
          if alerts then
            names[#names+1] = seq.name()
          end
          local col1 = collectionout(str,": [","]\n")
          seq.serialize(
            opts,
            function()
              col.elem(format("\"%s\"",seq.name()))
              col1.head()
            end,
            function(sum,hits,timestamp)
              col1.elem(format("[%d,%d,%s]",sum,hits,timestamp))
          end)
          col1.tail()
        end
      end
    end
    increment("mule.mulelib.graph",count)
    if in_memory then
      return in_memory
    end

    if alerts then
      col.elem(format("\"alerts\": %s",output_alerts(names).get_string()))
    end

    col.tail()

    return wrap_json(str)
  end



  local function slot(resource_,options_)
    local str = strout("")
    local format = string.format
    local opts = { timestamps={options_ and options_.timestamp},readable=is_true(options_.readable) }
    local col = collectionout(str,"{","}")

    col.head()
    each_metric(db_,resource_,nil,
                function(seq)
                  local col1 = collectionout(str,"[","]\n")
                  flush_cache_of_sequence(seq)
                  seq.serialize(opts,
                                function()
                                  col.elem(format("\"%s\": ",seq.name()))
                                  col1.head()
                                end,
                                function(sum,hits,timestamp)
                                  col1.elem(format("[%d,%d,%s]",sum,hits,timestamp))
                                end
                  )
                  col1.tail()
                end
    )

    col.tail()

    return wrap_json(str)
  end

  local function latest(resource_,opts_)
    opts_ = opts_ or {}
    opts_.timestamp = "latest"
    return slot(resource_,opts_)
  end


  local function key(resource_,options_)
    local str = strout("")
    local format = string.format
    local find = string.find
    local col = collectionout(str,"{","}")
    local level = tonumber(options_.level) or 0
    local count = 0
    col.head()

    if not resource_ or resource_=="" or resource_=="*" then
      -- we take the factories as distinct prefixes
      resource_ = table.concat(distinct_prefixes(keys(_factories)),"/")
      level = level - 1
    end
    local selector = db_.matching_keys
    -- we are abusing the level param to hold the substring to be search, to make the for loop easier
    if options_.substring then
      selector = db_.find_keys
      level = options_.substring
    end

    logd("key - start traversing")
    for prefix in split_helper(resource_ or "","/") do
      for k in selector(prefix,level) do
        local metric,_,_ = split_name(k)
        count = count+1
        if metric then
          local hash = db_.has_sub_keys(metric) and "{\"children\": true}" or "{}"
          col.elem(format("\"%s\": %s",k,hash))
        end
      end
    end
    increment("mule.mulelib.key",count)
    logd("key - done traversing")
    col.tail()
    return wrap_json(str)
  end


  local function kvs_put(key_,value_)
    return _db.put("kvs="..key_,value_)
  end

  local function kvs_get(key_)
    return _db.get("kvs="..key_,true)
  end

  local function kvs_out(key_)
    return _db.out("kvs="..key_,true)
  end

  local function save(skip_flushing_)
    logi("save",table_size(_factories),table_size(_alerts),table_size(_hints))
    _db.put("metadata=version",pp.pack(CURRENT_VERSION))
    _db.put("metadata=factories",pp.pack(_factories))
    _db.put("metadata=alerts",pp.pack(_alerts))
    _db.put("metadata=hints",pp.pack({})) -- we don't save the hints but recalc them every time we start
    logi("save - flushing uncommited data",skip_flushing_)
    while not skip_flushing_ and flush_cache(UPDATE_AMOUNT) do
      -- nop
    end
  end

  local function reset(resource_,options_)
    local timestamp = to_timestamp(options_.timestamp,time_now(),nil)
    local level = tonumber(options_.level) or 0
    local force = is_true(options_.force)
    local str = strout("","\n")
    local format = string.format
    local col = collectionout(str,"[","]")
    local timestamp = tonumber(options_.timestamp)

    col.head()
    if resource_=="" then
      logw("reset - got empty key. bailing out");
    else
      for name in db_.matching_keys(resource_,level) do
        if force then
          logi("reset",name)
          _updated_sequences[name] = nil
          _db.out(name)
          col.elem(format("\"%s\"",name))
        elseif timestamp then
          flush_cache_of_sequence(name)
          local seq = sequence(db_,name)
          logi("reset to timestamp",name,timestamp)
          if seq.reset_to_timestamp(timestamp) then
            col.elem(format("\"%s\"",name))
          end
        end
      end
    end

    col.tail()

    return wrap_json(str)
  end

  local function alert_set(resource_,options_)
    if not resource_ or #resource_==0 then
      return nil
    end
    local metric,step,period = split_name(resource_)

    local new_alert = {
      _critical_low = tonumber(options_.critical_low),
      _warning_low = tonumber(options_.warning_low),
      _warning_high = tonumber(options_.warning_high),
      _critical_high = tonumber(options_.critical_high),
      _period = parse_time_unit(options_.period),
      _stale = parse_time_unit(options_.stale),
      _sum = 0,
      _state = ""
    }

    local function compare_with_existing()
      if not _alerts[resource_] then
        return false
      end
      local fields = {
        "_critical_low",
        "_warning_low",
        "_warning_high",
        "_critical_high",
        "_period",
        "_stale"
      }
      local existing = _alerts[resource_]

      for _,f in ipairs(fields) do
        if new_alert[f]~=existing[f] then
          return false
        end
      end
      return true
    end

    if not (metric and step and period and
              new_alert._critical_low and new_alert._warning_low and
              new_alert._critical_high and new_alert._warning_high and
            new_alert._period) then
      logw("alert_set threshold ill defined",resource_,t2s(options_),t2s(new_alert))
      return nil
    end

    -- idempotent is king
    if compare_with_existing() then
      return ""
    end

    _alerts[resource_] = new_alert
    -- we now force a check to fill in the current state
    local seq = sequence(_db,resource_)
    alert_check(seq,time_now())
    logi("set alert",resource_,t2s(_alerts[resource_]))
    save(true)
    return ""
  end

  local function alert_remove(resource_)
    if not _alerts[resource_] then
      logw("alert not found",resource_)
      return nil
    end

    _alerts[resource_] = nil
    logi("remove alert",resource_)
    save()
    return ""
  end

  local function alert(resource_)
    local as = #resource_>0 and split(resource_,"/") or keys(_alerts)
    return wrap_json(output_alerts(as,#resource_==0))
  end

  local function merge_lines(sorted_file_,step_,period_,now_)
    local last_metric,seq
    local str = stdout("")
    local format = string.format
    local period = parse_time_unit(period_)

    local function output_sequence(metric_,seq_)
      for _,s in ipairs(seq_.slots()) do
        str.write(metric_," ",s._sum," ",s._timestamp," ",s._hits,"\n")
      end
    end

    function helper(f)
      for l in f:lines() do
        local items,t = parse_input_line(l)
        if t=="command" then
          logw("sorted_line - command in input file. ignoring",l)
        else
          if items[1]~=last_metric then
            if seq then
              output_sequence(last_metric,seq)
            end
            last_metric = items[1]
            seq = sparse_sequence(format("%s;%s:%s",last_metric,step_,period_))
          end

          local timestamp,hits,sum,_ = legit_input_line(items[1],items[2],items[3],items[4])
          if not timestamp then
            logw("merge_lines - bad params",l)
          elseif timestamp>now_-period then
            seq.update(timestamp,hits,sum)
          end
        end

      end

      if seq then
        output_sequence(seq)
      end
      return true
    end

    with_file(sorted_file_,helper)
  end

  local function command(items_)
    local func = items_[1]
    local dispatch = {
      graph = function()
        return graph(items_[2],qs_params(items_[3]))
      end,
      key = function()
        return key(items_[2],qs_params(items_[3]))
      end,
      alert = function()
        return alert(items_[2])
      end,
      alert_remove = function()
        return alert_remove(items_[2])
      end,
      alert_set= function()
        return alert_set(items_[2],{
                           critical_low = items_[3],
                           warning_low = items_[4],
                           warning_high = items_[5],
                           critical_high = items_[6],
                           period = items_[7],
                           stale = items_[8],
        })
      end,
      latest = function()
        return latest(items_[2],qs_params(items_[3]))
      end,
      slot = function()
        return slot(items_[2],qs_params(items_[3]))
      end,
      gc = function()
        return gc(items_[2],qs_params(items_[3]))
      end,
      reset = function()
        return reset(items_[2],qs_params(items_[3]))
      end,
      dump = function()
        return dump(items_[2],qs_params(items_[3]))
      end,
      merge_lines = function()
        return merge_lines(items_[2],items_[3],items_[4],items_[5])
      end,
    }

    if dispatch[func] then
      increment("mule.mulelib.command."..func)
      return dispatch[func]()
    end
    loge("unknown command",func)
  end

  local function configure(configuration_lines_)
    for l in lines_without_comments(configuration_lines_) do
      local items,t = parse_input_line(l)
      if t then
        logw("unexpexted type",type)
      else
        local metric = items[1]
        table.remove(items,1)
        add_factory(metric,items)
      end
    end
    logi("configure",table_size(_factories))
    save(true)
    return table_size(_factories)
  end

  local function export_configuration()
    local str = strout("")
    local format = string.format
    local col = collectionout(str,"{","}")

    col.head()
    for fm,rps in pairs(_factories) do
      local col1 = collectionout(str,"[","]\n")
      col.elem(format("\"%s\": ",fm))
      col1.head()
      for _,v in ipairs(rps) do
        col1.elem(format("\"%s:%s\" ",secs_to_time_unit(v[1]),secs_to_time_unit(v[2])))
      end
      col1.tail()
    end
    col.tail()
    logi("export_configuration",table_size(_factories))
    return wrap_json(str)
  end

  local function factories_out(resource_,options_)
    local str = strout("")
    local format = string.format
    local col = collectionout(str,"{","}")
    local force = is_true(options_ and options_.force)

    col.head()
    for fm in split_helper(resource_,"/") do
      local rps = _factories[fm]
      if force then
        _factories[fm] = nil
      end
      if rps then
        local col1 = collectionout(str,"[","]\n")
        col.elem(format("\"%s\": ",fm))
        col1.head()
        for _,v in ipairs(rps) do
          col1.elem(format("\"%s:%s\" ",secs_to_time_unit(v[1]),secs_to_time_unit(v[2])))
        end
        col1.tail()
      end
    end
    col.tail()
    logi("factories_out",table_size(_factories))
    uniq_factories()
    return wrap_json(str)
  end

  local function load()
    logi("load")
    local function helper(key_,dont_cache_,default_)
      local v = _db.get(key_,dont_cache_)
      return v and pp.unpack(v) or default_
    end

    local version = helper("metadata=version",true,CURRENT_VERSION)
    if not version==CURRENT_VERSION then
      error("unknown version")
      return nil
    end

    _factories = helper("metadata=factories",true,{})
    -- there was a bug which caused factories to be non-uniq so we fix it
    uniq_factories()
    _alerts = helper("metadata=alerts",true,{})
    _hints = {}
    logi("load",table_size(_factories),table_size(_alerts),table_size(_hints))
  end


  update_sequence = function(name_,sum_,timestamp_,hits_,type_,now_)
    if now_ then
      local metric,step,period = parse_name(name_)
      if timestamp_<now_-period then
        return false
      end
    end

    local seq = _updated_sequences[name_]
    local new_key = false
    if not seq then
      -- this might be a new key and so we should add it to the DB as well. Kind of ugly, but we rely on the
      -- DB (and not the caches) when looking for keys
      seq = sparse_sequence(name_)
      new_key = true
    end
    local adjusted_timestamp,sum = seq.update(timestamp_,hits_,sum_,type_)
    -- it might happen that we try to update a too old timestamp. In such a case
    -- the update function returns null
    if adjusted_timestamp then
      _updated_sequences[name_] = seq
      if new_key then
        flush_cache_of_sequence(name_,seq)
      end
    end
    return true
  end

  local function update_line(metric_,sum_,timestamp_,hits_,now_)
    local timestamp,hits,sum,typ = legit_input_line(metric_,sum_,timestamp_,hits_)

    if not timestamp then
      logw("update_line - bad params",metric_,sum_,timestamp_)
      return
    end
    if sum==0 then -- don't bother to update
      return
    end

    for n,_ in get_sequences(metric_) do
      update_sequence(n,sum,timestamp,hits,typ,now_)
    end

  end

  local function flush_all_caches(amount_,step_)
    amount_ = amount_ or UPDATE_AMOUNT
    local fc1 = flush_cache(amount_,step_)
    local fc2 = _db.flush_cache(amount_/4,step_)
    return fc1 or fc2
  end


  local function modify_factories(factories_modifications_)
    -- the factories_modifications_ is a list of triples,
    -- <pattern, original retention, new retention>
    for _,f in ipairs(factories_modifications_) do
      local factory = _factories[f[1]]
      if factory then
        local orig_step,orig_period = parse_time_pair(f[2])
        local new_step,new_period = parse_time_pair(f[3])
        for j,r in ipairs(factory) do
          if r[1]==orig_step and r[2]==orig_period then
            logd("found original factory:",f[1])
            factory[j] = {new_step,new_period}
            -- scan the metrics hierarchy. every matching sequence should be replaced with
            -- a new retention
            for seq in sequences_for_prefix(_db,f[1],f[2]) do
              logd("found original sequence:",seq.name())
              local new_name = name(seq.metric(),new_step,new_period)
              sequence(db_,new_name).update_batch(seq.slots(),0,1,2)
              _db.out(seq.name())
            end
          end
        end
      else
        logw("pattern not found",f[1])
      end
    end
    flush_all_caches()
  end

  local function process_line(metric_line_,no_commands_)
    local function helper()
      local items,t = parse_input_line(metric_line_)

      if #items==0 then
        if #metric_line_>0 then
          logd("bad input",metric_line_)
        end
        return nil
      end

      if t=="command" then
        return not no_commands_ and command(items)
      end
      -- there are 2 line formats:
      -- 1) of the format metric sum timestamp
      -- 2) of the format (without the brackets) name (sum hits timestamp)+

      -- 1) standard update
      if not string.find(items[1],";",1,true) then
        return update_line(items[1],items[2],items[3],items[4])
      end

      -- 2) an entire sequence
      local name = items[1]
      table.remove(items,1)
      -- here we DON'T use the sparse sequence as they aren't needed when reading an
      -- entire sequence
      -- TODO might be a corrupted line with ';' accidently in the line.
      return sequence(_db,name).update_batch(items,2,1,0)
    end

    local success,rv = pcall(helper)
    if success then
      return rv
    end
    logw("process_line error",rv,metric_line_)
    return nil

  end

  local function process(data_,dont_update_,no_commands_)
    local lines_count = 0

    local function spillover_protection()
      -- we protect from _updated_sequences growing too large if the input data is large
      lines_count = lines_count + 1
      if lines_count==UPDATED_SEQUENCES_MAX then
        logi("process - forcing an update",lines_count)
        flush_cache(UPDATE_AMOUNT)
        lines_count = lines_count - UPDATE_AMOUNT
      end
    end

    -- strings are handled as file pointers if they exist or as a line
    -- tables as arrays of lines
    -- functions as iterators of lines
    local function helper()
      if type(data_)=="string" then
        local file_exists = with_file(data_,
                                      function(f)
                                        for l in f:lines() do
                                          process_line(l,no_commands_)
                                          spillover_protection()
                                        end
                                        return true
        end)
        if file_exists then
          return true
        end
        return process_line(data_)
      end

      if type(data_)=="table" then
        local rv
        for _,d in ipairs(data_) do
          rv = process_line(d)
          spillover_protection()
        end
        return rv
      end

      -- we assume it is a function
      local rv
      local count = 0
      for d in data_ do
        rv = process_line(d)
        count = count + 1
        spillover_protection()
      end
      logd("processed",count)
      return rv
    end


    local rv = helper()
    if not dont_update_ then
      flush_all_caches()
    end
    return rv
  end

  local function matching_sequences(metric_)
    local seqs = {}
    each_metric(_db,metric_,nil,
                function(seq)
                  table.insert(seqs,seq)
    end)
    return seqs
  end

  return {
    configure = configure,
    export_configuration = export_configuration,
    factories_out = factories_out,
    matching_sequences = matching_sequences,
    get_factories = function() return _factories end,
    reset = reset,
    dump = dump,
    graph = graph,
    key = key,
    gc = gc,
    latest = latest,
    slot = slot,
    modify_factories = modify_factories,
    process = process,
    flush_cache = flush_all_caches,
    save = save,
    load = load,
    alert_set = alert_set,
    alert_remove = alert_remove,
    alert = alert,
    kvs_put = kvs_put,
    kvs_get = kvs_get,
    kvs_out = kvs_out,
  }
end
