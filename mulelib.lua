require "helpers"
local pp = require("purepack")
require "conf"
require "calculate_fdi_30"

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

  local function get_hits(idx_)
    return at(idx_,1)
  end

  local function get_sum(idx_)
    return at(idx_,2)
  end

  local function latest(idx_)
    local pos = math.floor(_period/_step)
    if not idx_ then
      return at(pos,0)
    end
    at(pos,0,idx_)
  end

  local function latest_timestamp()
    return get_timestamp(latest())
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

  local function update(timestamp_,hits_,sum_,replace_)
    local idx,adjusted_timestamp = calculate_idx(timestamp_,_step,_period)
    local timestamp,hits,sum = at(idx)

    -- we need to check whether we should update the current slot
    -- or if are way ahead of the previous time the slot was updated
    -- over-write its value
    if adjusted_timestamp<timestamp then
      return
    end

    -- chasing a bug {
    if timestamp~=0 and ((adjusted_timestamp-timestamp) % _period)~=0 then
      logw("update - seems like the wrong idx was calculated",name_,_period,idx,adjusted_timestamp,timestamp,hits,sum,timestamp_,sum_,hits_,replace_)
      -- to override the faulty value
      hits = 0
      sum = 0
    end
    -- }

    if (not replace_) and adjusted_timestamp==timestamp and hits>0 then
      -- no need to worry about the latest here, as we have the same (adjusted) timestamp
      hits,sum = hits+(hits_ or 1), sum+sum_
    else
      hits,sum = hits_ or 1,sum_
    end
    at(idx,nil,adjusted_timestamp,hits,sum)
    local lt = latest_timestamp()
    if adjusted_timestamp>lt then
      latest(idx)
    end

    _seq_storage.save(_name)
    return adjusted_timestamp,sum
  end

  local function update_batch(slots_)
    -- slots is a flat array of arrays
    local j = 1
    local match = string.match
    while j<#slots_ do
      local sum,hits,timestamp = tonumber(slots_[j]),tonumber(slots_[j+1]),tonumber(slots_[j+2])
      j = j + 3
      local replace,s = match(sum,"(=?)(%d+)")
      update(timestamp,hits,tonumber(s),replace)
    end

    _seq_storage.save(_name)
    return j-1
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

  local function serialize(opts_,metric_cb_,slot_cb_)
    local date = os.date


    local function serialize_slot(idx_,skip_empty_,slot_cb_,readable_)
      local timestamp,hits,sum = at(idx_)
      if not skip_empty_ or sum~=0 or hits~=0 or timestamp~=0 then
        slot_cb_(sum,hits,readable_ and date("%y%m%d:%H%M%S",timestamp) or timestamp)
      end
    end

    opts_ = opts_ or {}
    metric_cb_(_metric,_step,_period)

    local now = time_now()
    local latest_ts = latest_timestamp()
    local readable = opts_.readable
    local min_timestamp = (opts_.filter=="latest" and latest_ts-_period) or
      (opts_.filter=="now" and now-_period) or nil
    if opts_.all_slots then
      if not opts_.dont_cache then
        _seq_storage.cache(name_) -- this is a hint that the sequence can be cached
      end
      for s in indices(opts_.sorted) do
        if not min_timestamp or min_timestamp<get_timestamp(s) then
          serialize_slot(s,opts_.skip_empty,slot_cb_,readable)
        end
      end
      return
    end

    if opts_.timestamps then
      for _,t in ipairs(opts_.timestamps) do
        if t=="*" then
          for s in indices(opts_.sorted) do
            serialize_slot(s,true,slot_cb_,readable)
          end
        else
          local ts = to_timestamp(t,now,latest_ts)
          if ts then
            if type(ts)=="number" then
              ts = {ts,ts+_step-1}
            end
            for t = ts[1],ts[2],(ts[1]<ts[2] and _step or -_step) do
              local idx,_ = calculate_idx(t,_step,_period)
              local its = get_timestamp(idx)
              if t-its<_period and (not min_timestamp or min_timestamp<its) then
                serialize_slot(idx,true,slot_cb_,readable)
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

  local function uniq_factories()
    local factories = _factories
    _factories = {}
    for fm,rps in pairs(factories) do
      _factories[fm] = uniq_pairs(rps)
    end
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
        for fm,rps in pairs(_factories) do
          if is_prefix(metric_,fm) then
            table.insert(metric_rps,{fm,rps})
          end
        end
        for m in metric_hierarchy(metric_) do
          for _,frp in ipairs(metric_rps) do
            if is_prefix(m,frp[1]) then
              for _,rp in ipairs(frp[2]) do
                coroutine.yield(name(m,rp[1],rp[2]),m)
              end
            end
          end
        end
      end)
  end



  local function gc(resource_,options_)
    local garbage = {}
    local str = strout("","\n")
    local format = string.format
    local col = collectionout(str,"[","]")
    local timestamp = tonumber(options_.timestamp)

    col.head()

    each_metric(_db,resource_,nil,
                  function(seq)
                    if seq.latest_timestamp()<timestamp then
                      col.elem(format("\"%s\"",seq.name()))
                      garbage[#garbage+1] = seq.name()
                    end
                  end)
    col.tail()

    if options_.force then
      for _,name in ipairs(garbage) do
        _sequences.out(name)
      end
    end

    return wrap_json(str)
  end

  local function reset(resource_,options_)
    for name in db_.matching_keys(resource_) do
      _db.out(name)
    end
    return true
  end



  local function dump(resource_,options_)
    local str = options_.to_str and strout("") or stdout("")
    local serialize_opts = {all_slots=true,skip_empty=true,dont_cache=true} -- caching kills us when dumping large DBs

    each_metric(_db,resource_,nil,
                function(seq)
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

  local function update_rank(rank_timestamp_,rank_,timestamp_,value_,name_,step_)
    local ts,rk,same_ts = update_rank_helper(rank_timestamp_,rank_,timestamp_,value_,step_)
    return ts,rk
  end

  local function graph(resource_,options_)
    local str = strout("")
    options_ = options_ or {}
    local timestamps = options_.timestamp and split(options_.timestamp,',') or nil
    local format = string.format
    local col = collectionout(str,"{","}")
    local opts = { all_slots=not timestamps,
                   filter=options_.filter,
                   readable=options_.readable,
                   timestamps=timestamps,
                   sorted=false,
                   skip_empty=true}
    local sequences_generator = immediate_metrics
    local alerts = is_true(options_.alerts)
    local names = {}
    local level = options_.level and tonumber(options_.level)
    local insert = table.insert
    local now = time_now()
    local find = string.find
    local in_memory = options_.in_memory and {}

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
              col1.elem(format("[%d,%d,%d]",sum,hits,timestamp))
          end)
          col1.tail()
        end
      end
    end

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
    local opts = { timestamps={options_ and options_.timestamp} }
    local col = collectionout(str,"{","}")

    col.head()
    each_metric(db_,resource_,nil,
                function(seq)
                  local col1 = collectionout(str,"[","]\n")
                  seq.serialize(opts,
                                function()
                                  col.elem(format("\"%s\": ",seq.name()))
                                  col1.head()
                                end,
                                function(sum,hits,timestamp)
                                  col1.elem(format("[%d,%d,%d]",sum,hits,timestamp))
                                end
                  )
                  col1.tail()
                end
    )

    col.tail()

    return wrap_json(str)
  end

  local function latest(resource_)
    return slot(resource_,{timestamp="latest"})
  end


  local function key(resource_,options_)
    local str = strout("")
    local format = string.format
    local find = string.find
    local col = collectionout(str,"{","}")
    local level = tonumber(options_.level) or 0
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
        if metric then
          local hash = db_.has_sub_keys(metric) and "{\"children\": true}" or "{}"
          col.elem(format("\"%s\": %s",k,hash))
        end
      end
    end
    logd("key - done traversing")
    col.tail()
    return wrap_json(str)
  end


  local function flush_cache(max_,step_)
    _flush_cache_logger()

    -- we now update the real sequences
    local now = time_now()
    local num_processed = 0
    local size,st,en = random_table_region(_updated_sequences,max_)
    if size==0 then return false end

    for n,s in iterate_table(_updated_sequences,st,en) do
      local seq = sequence(_db,n)
      for j,sl in ipairs(s.slots()) do
        local adjusted_timestamp,sum = seq.update(sl._timestamp,sl._hits or 1,sl._sum,
                                                  sl._hits==nil)
        if adjusted_timestamp and sum then
          _hints[n] = _hints[n] or {}
          if not _hints[n]._rank_ts then
            _hints[n]._rank = 0
            _hints[n]._rank_ts = 0
          end
          _hints[n]._rank_ts,_hints[n]._rank = update_rank(
            _hints[n]._rank_ts,_hints[n]._rank,
            adjusted_timestamp,sum,n,seq.step())
        end
        alert_check(seq,now)
      end
      _updated_sequences[n] = nil
      num_processed = num_processed + 1
    end
    if num_processed==0 then return false end
    -- returns true if there are more items to process
    return _updated_sequences and next(_updated_sequences)~=nil
  end



  local function save(skip_flushing_)
    logi("save",table_size(_factories),table_size(_alerts),table_size(_hints))
    _db.put("metadata=version",pp.pack(CURRENT_VERSION),true)
    _db.put("metadata=factories",pp.pack(_factories),true)
    _db.put("metadata=alerts",pp.pack(_alerts),true)
    _db.put("metadata=hints",pp.pack({}),true) -- we don't save the hints but recalc them every time we start
    logi("save - flushing uncommited data",skip_flushing_)
    while not skip_flushing_ and flush_cache(UPDATE_AMOUNT) do
      -- nop
    end
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

    if not (metric and step and period and
            new_alert._critical_low and new_alert._warning_low and
            new_alert._critical_high and new_alert._warning_high and
            new_alert._period) then
      logw("alert_set threshold ill defined",resource_,t2s(options_),t2s(new_alert))
      return nil
    end

    _alerts[resource_] = new_alert

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

  local function fdi(resource_,options_)
    local str = strout("")
    local col = collectionout(str,"{","}")
    local now = time_now()
    local last_days = to_timestamp(ANOMALIES_LAST_DAYS,now,nil)
    local today = normalize_timestamp(now,3600*24)
    local insert = table.insert
    local format = string.format
    col.head()
    options_ = options_ or {}
    options_["in_memory"] = true
    local graphs = graph(resource_,options_)
    logd("fdi - got graphs")

    for k,v in pairs(graphs) do
      local metric,step,period = split_name(k)
      logd("fdi",parse_time_unit(step),k)
      if metric and step and period then
        local anomalies = {}
        for _,vv in ipairs(calculate_fdi(now,parse_time_unit(step),v) or {}) do
          if vv[2] and vv[1]~=today then -- we ignore today as it is likely to have only very partial data
            insert(anomalies,vv[1])
          end
        end
        if #anomalies>0 and anomalies[#anomalies]>=last_days then
          _anomalies[k] = anomalies
          local ar = table.concat(anomalies,",")
          col.elem(format("\"%s\": [%s]",k,ar))
          logd("fdi - anomalies detected",most_recent,today,k,ar)
        else
          _anomalies[k] = nil
        end
      else
        loge("fdi - bad input",k)
      end
    end
    col.tail()

    -- add cleanup of outdated anomalies
    for k,v in pairs(_anomalies) do
      if v[#v]<last_days then
        _anomalies[k] = nil
      end
    end
    return wrap_json(str)
  end

  local function command(items_)
    local func = items_[1]
    local dispatch = {
      graph = function()
        return graph(items_[2],{timestamp=items_[3]})
      end,
      key = function()
        return key(items_[2],{timestamp=items_[3]})
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
        return latest(items_[2])
      end,
      slot = function()
        return slot(items_[2],{timestamp=items_[3]})
      end,
      gc = function()
        return gc(items_[2],{timestamp=items_[3],force=is_true(items_[4])})
      end,
      reset = function()
        return reset(items_[2])
      end,
      dump = function()
        return dump(items_[2],{to_str=is_true(items_[3])})
      end,
    }

    if dispatch[func] then
      return dispatch[func]()
    end
    loge("unknown command",func)
  end

  local function configure(configuration_lines_)
    for l in lines_without_comments(configuration_lines_) do
      local items,type = parse_input_line(l)
      if type then
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


  local function update_line(metric_,sum_,timestamp_)
    local replace,sum = string.match(sum_ or "","(=?)(%d+)")
    replace = replace=="="
    timestamp_ = tonumber(timestamp_)
    sum = tonumber(sum)

    if not metric_ or #metric_>MAX_METRIC_LEN or not sum_ or not timestamp_ then
      logw("update_line - bad params",metric_,sum_,timestamp_)
      return
    end
    for n,m in get_sequences(metric_) do
      local seq = _updated_sequences[n] or sparse_sequence(n)
      local adjusted_timestamp,sum = seq.update(timestamp_,1,sum,replace)
      -- it might happen that we try to update a too old timestamp. In such a case
      -- the update function returns null
      if adjusted_timestamp then
        _updated_sequences[n] = seq
      end
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
              sequence(db_,new_name).update_batch(seq.slots())
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
      local items,type = parse_input_line(metric_line_)
      if #items==0 then
        if #metric_line_>0 then
          logd("bad input",metric_line_)
        end
        return nil
      end

      if type=="command" then
        return not no_commands_ and command(items)
      end
      -- there are 2 line formats:
      -- 1) of the format metric sum timestamp
      -- 2) of the format (without the brackets) name (sum hits timestamp)+

      -- 1) standard update
      if not string.find(items[1],";",1,true) then
        return update_line(items[1],items[2],items[3])
      end

      -- 2) an entire sequence
      local name = items[1]
      table.remove(items,1)
      -- here we DON'T use the sparse sequence as they aren't needed when reading an
      -- entire sequence
      -- TODO might be a corrupted line with ';' accidently in the line.
      return sequence(_db,name).update_batch(items)
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
    fdi = fdi
         }
end
