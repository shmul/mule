require "helpers"
local pp = require "purepack"
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

  local function get_hits(idx_)
    return at(idx_,1)
  end

  local function get_sum(idx_)
    return at(idx_,2)
  end


  local function set_slot(idx_,timestamp_,hits_,sum_)
    at(idx_,nil,timestamp_,hits_,sum_)
  end

  local function latest(idx_)
    local pos = (_period/_step)
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
    loge("failed generating sequence",name_)
    return NOP_SEQUENCE
  end

  _seq_storage = db_.sequence_storage(name_,_period/_step)


  local function update(timestamp_,sum_,hits_,replace_)
    local idx,adjusted_timestamp = calculate_idx(timestamp_,_step,_period)
    -- if this value is way back (but still fits in this slot)
    -- we discard it
    local timestamp,hits,sum = at(idx)

    if adjusted_timestamp<timestamp then
      return
    end
    -- we need to check whether we should update the current slot
    -- or if are way ahead of the previous time the slot was updated
    -- over-write its value

    if not replace_ and adjusted_timestamp==timestamp and hits>0 then
      -- no need to worry about the latest here, as we have the same (adjusted) timestamp
      hits,sum = hits+(hits_ or 1), sum+sum_
    else
      hits,sum = hits_ or 1,sum_
    end
    set_slot(idx,adjusted_timestamp,hits,sum)

    if adjusted_timestamp>latest_timestamp() then
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
      local sum,hits,timestamp = slots_[j],tonumber(slots_[j+1]),tonumber(slots_[j+2])
      j = j + 3
      local replace,s = match(sum,"(=?)(%d+)")
      update(timestamp,s,hits,replace)
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

    local function serialize_slot(idx_,skip_empty_,slot_cb_)
      local timestamp,hits,sum = at(idx_)
      if not skip_empty_ or sum~=0 or hits~=0 or timestamp~=0 then
        -- due to some bug we may have sum~timestamp, in such case we return 0
        if sum>=1380000000 then
          sum = 0
        end
        slot_cb_(sum,hits,timestamp)
      end
    end

    opts_ = opts_ or {}
    metric_cb_(_metric,_step,_period)

    local now,latest_ts = time_now(),latest_timestamp()
    local min_timestamp = (opts_.filter=="latest" and latest_ts-_period) or
      (opts_.filter=="now" and now-_period) or nil


    if opts_.deep then
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
            serialize_slot(s,nil,slot_cb_)
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
                serialize_slot(idx,nil,slot_cb_)
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

-- sparse sequences are expected to have very few (usually one) non empty slots, so we use
-- a plain (non sorted) array

function sparse_sequence(name_)
  local _metric,_step,_period
  local _slots = {}

  _metric,_step,_period = string.match(name_,"^(.+);(%w+):(%w+)$")
  _step = parse_time_unit(_step)
  _period = parse_time_unit(_period)

  local function find_slot(timestamp_)
    for i,s in ipairs(_slots) do
      if s._timestamp==timestamp_ then return s end
    end
    table.insert(_slots,{ _timestamp = timestamp_, _hits = 0, _sum = 0})
    return _slots[#_slots]
  end

  local function update(timestamp_,sum_,hits_,replace_)
    local _,adjusted_timestamp = calculate_idx(timestamp_,_step,_period)
    -- here, unlike the regular sequence, we keep all the timestamps. The real sequence
    -- will discard stale ones
    local slot = find_slot(adjusted_timestamp)
    if replace_ then
      slot._sum = sum_
      slot._hits = nil -- we'll use this as an indication or replace
    else
      slot._sum = slot._sum+sum_
      slot._hits = slot._hits+hits_
    end
    return adjusted_timestamp,slot._sum
  end

  return {
    update = update,
    slots = function() return _slots end
         }
end

local function sequences_for_prefix(db_,prefix_,retention_pair_)
  return coroutine.wrap(
    function()
      local find = string.find
      local yield = coroutine.yield
      prefix_ = (prefix_=="*" and "") or prefix_
      for name in db_.matching_keys(prefix_) do
        if not retention_pair_ or find(name,retention_pair_,1,true) then
          yield(sequence(db_,name))
        end
      end
    end)
end

function one_level_children(db_,name_)
  return coroutine.wrap(
    function()
      local prefix,rp = string.match(name_,"(.-);(.+)")
      if not prefix or not rp then
        prefix = name_
        rp = ""
      end
      local find = string.find
      for name in db_.matching_keys(prefix) do
        if name~=prefix and find(name,rp,1,true) and
          (#prefix>0 and not find(name,".",#prefix+2,true)) then
          -- we are intersted only in child metrics of the format
          -- m.sub-key;ts where sub-key contains no dots
          coroutine.yield(sequence(db_,name))
        end
      end
    end)
end

function immediate_metrics(db_,name_)
  return coroutine.wrap(
    function()
      local find = string.find
      if find(name_,";",1,true) then
        coroutine.yield(sequence(db_,name_))
      else
        for name in db_.matching_keys(name_) do
          if not find(name,".",#name_+1,true) then
            coroutine.yield(sequence(db_,name))
          end
        end
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


local function each_sequence(db_,prefix_,retention_pair_,callback_)
  for seq in sequences_for_prefix(db_,prefix_,retention_pair_) do
    callback_(seq)
  end
end

local function each_metric(db_,metrics_,retention_pair_,callback_)
  for m in split_helper(metrics_,"/") do
    each_sequence(db_,m,retention_pair_,callback_)
  end
end

function mule(db_)
  local _factories = {}
  local _alerts = {}
  local _db = db_
  local _updated_sequences = {}
  local _hints = {}

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

    each_sequence(_db,resource_,nil,
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
    each_sequence(_db,resource_,nil,
                  function(seq)
                    _db.out(seq.name())
                  end)
    return true
  end



  local function dump(resource_,options_)
    local str = options_.to_str and strout("") or stdout("")
    local format = string.format

    each_metric(_db,resource_,nil,
                function(seq)
                  seq.serialize({deep=true,skip_empty=true},
                                function()
                                  str.write(seq.name())
                                end,
                                function(sum,hits,timestamp)
                                  str.write(format(" %d %d %d",sum,hits,timestamp))
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

    if alert._stale and seq_.latest_timestamp()+alert._stale<timestamp_ then
      alert._state = "stale"
      return true
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
          average_sum = slot._sum*(start-slot._timestamp)/step
        else
          average_sum = average_sum + slot._sum
        end
      end
    end

    alert._sum = average_sum
    alert._state = (average_sum<alert._critical_low and "CRITICAL LOW") or
      (average_sum<alert._warning_low and "WARNING LOW") or
      (average_sum>alert._critical_high and "CRITICAL HIGH") or
      (average_sum>alert._warning_high and "WARNING HIGH") or
      "NORMAL"
    return alert
  end

  local function output_alerts(names_)
    local str = strout("","\n")
    local format = string.format
    local col = collectionout(str,"{","}")
    local now = time_now()
    col.head()

    for _,n in ipairs(names_) do
      local seq = sequence(db_,n)
      local a = alert_check(seq,now)
      if a then
        col.elem(format("\"%s\": [%d,%d,%d,%d,%d,%s,%d,\"%s\"]",
                        n,a._critical_low,a._warning_low,a._warning_high,a._critical_high,
                        a._period,a._stale or "-1",a._sum,a._state))
      end
    end
    col.tail()
    return str
  end

  local function update_rank(rank_timestamp_,rank_,timestamp_,value_,name_,step_)
    local ts,rk,same_ts = update_rank_helper(rank_timestamp_,rank_,timestamp_,value_,step_)
    if same_ts then
      return ts,rk
    end

    -- new timestamp. We need to check for spikes
    if rank_*POSITIVE_SPIKE_FACTOR<rk or rank_*NEGATIVE_SPIKE_FACTOR>rk then
      -- TODO, we need to keep it around (in _alerts?)
      -- TODO small values should be shooshed
      logi("spike detected for",name_,timestamp_,rank_,rk)
    end
    return ts,rk
  end

  local function graph(resource_,options_)
    local str = strout("")
    options_ = options_ or {}
    local timestamps = options_.timestamp and split(options_.timestamp,',') or nil
    local format = string.format
    local col = collectionout(str,"{","}")
    local opts = { deep=not timestamps,
                   filter=options_.filter,
                   timestamps=timestamps,
                   sorted=false,
                   skip_empty=true}
    local depth = immediate_metrics
    local alerts = is_true(options_.alerts)
    local names = {}

    col.head()
    for m in split_helper(resource_,"/") do
      if m=="*" then m = "" end
      if is_true(options_.deep) then
        local ranked_children = {}
        local insert = table.insert
        local now = time_now()
        for seq in one_level_children(db_,m) do
          -- we call update_rank to get adjusted ranks (in case the previous update was
          -- long ago). This is a readonly operation
          local hint = _hints[seq.name()] or {}
          local _,seq_rank = update_rank(
            hint._rank_ts or 0 ,hint._rank or 0,
            normalize_timestamp(now,seq.step(),seq.period()),0,seq.name(),seq.step())
          insert(ranked_children,{seq,seq_rank})
        end
        table.sort(ranked_children,function(a,b) return a[2]>b[2] end)
        depth = function()
          return coroutine.wrap(
            function()
--              for s in immediate_metrics(db_,m) do
--                coroutine.yield(s)
--              end
              for i=1,(math.min(#ranked_children,options_.count or DEFAULT_COUNT)) do
                coroutine.yield(ranked_children[i][1])
              end
            end)
        end
      end

      for seq in depth(db_,m) do
        logd("graph - processing",seq.name())
        if alerts then
          names[#names+1] = seq.name()
        end
        local col1 = collectionout(str,": [","]\n")
        seq.serialize(opts,
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

    if alerts then
      col.elem(format("\"alerts\": %s",output_alerts(names).get_string()))
    end

    col.tail()
    return wrap_json(str)
  end



  local function piechart(resource_,options_)
    local opts = options_ or {}
    opts.deep = true
    return graph(resource_,opts)
  end



  local function slot(resource_,options_)
    local str = strout("")
    local format = string.format
    local opts = { timestamps={options_ and options_.timestamp} }
    local col = collectionout(str,"{","}")

    col.head()
    for m in split_helper(resource_,"/") do
      each_sequence(_db,m,nil,
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
                    end)
    end
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
    local level = tonumber(options_.level) or 1
    local deep = is_true(options_.deep)
    col.head()

    for prefix in split_helper(resource_ or "","/") do
      prefix = (prefix=="*" and "") or prefix
      for k in db_.matching_keys(prefix) do
        if deep or bounded_by_level(k,prefix,level) then
          local hash = (_hints[k] and _hints[k]._haschildren and "{\"children\": true}") or "{}"
          col.elem(format("\"%s\": %s",k,hash))

        end
      end
    end
    col.tail()
    return wrap_json(str)
  end

  local function save()
    logi("save",table_size(_factories),table_size(_alerts),table_size(_hints))
    _db.put("metadata=version",pp.pack(CURRENT_VERSION))
    _db.put("metadata=factories",pp.pack(_factories))
    _db.put("metadata=alerts",pp.pack(_alerts))
    _db.put("metadata=hints",pp.pack(_hints))
  end


  local function alert_set(resource_,options_)
    if not resource_ or #resource_==0 then
      return nil
    end
    _alerts[resource_] = {
      _critical_low = tonumber(options_.critical_low),
      _warning_low = tonumber(options_.warning_low),
      _warning_high = tonumber(options_.warning_high),
      _critical_high = tonumber(options_.critical_high),
      _period = parse_time_unit(options_.period),
      _stale = parse_time_unit(options_.stale),
      _sum = 0,
      _state = ""
    }

    if not _alerts[resource_]._period then
      logw("alert_set no period defined",t2s(options_))
      return nil
    end
    logi("set alert",resource_,t2s(_alerts[resource_]))
    save()
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
    return wrap_json(output_alerts(as))
  end

  local function command(items_)
    local func = items_[1]
    local dispatch = {
      graph = function()
        return graph(items_[2],{timestamp=items_[3]})
      end,
      piechart = function()
        return piechart(items_[2],{timestamp=items_[3]})
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
        return dump(items_[2],{to_str=is_true(items[3])})
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
    save()
    return table_size(_factories)
  end



  local function load()
    logi("load")
    local ver = _db.get("metadata=version")
    local factories = _db.get("metadata=factories")
    local alerts = _db.get("metadata=alerts")
    local hints = _db.get("metadata=hints")
    local version = ver and pp.unpack(ver) or CURRENT_VERSION
    if not version==CURRENT_VERSION then
      error("unknown version")
      return nil
    end
    _factories = factories and pp.unpack(factories) or {}
    _alerts = alerts and pp.unpack(alerts) or {}
    _hints = hints and pp.unpack(hints) or {}
    logi("load",table_size(_factories),table_size(_alerts),table_size(_hints))
  end


  local function update_line(metric_,sum_,timestamp_)
    local replace,sum = string.match(sum_,"(=?)(%d+)")
    replace = replace=="="
    timestamp_ = tonumber(timestamp_)
    if not metric_ or not sum_ or not timestamp_ then
      logw("update_line - missing params")
      return
    end
    for n,m in get_sequences(metric_) do
      local seq = _updated_sequences[n] or sparse_sequence(n)
      local adjusted_timestamp,sum = seq.update(timestamp_,sum,1,replace)
      -- it might happen that we try to update a too old timestamp. In such a case
      -- the update function returns null
      if adjusted_timestamp then
        _updated_sequences[n] = seq
        if m~=metric_ then -- we check the metric, but the *name* is updated
          _hints[n] = _hints[n] or {}
          _hints[n]._haschildren = true
        end
      end
    end
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
  end

  local function process_line(metric_line_)
    local function helper()
      local items,type = parse_input_line(metric_line_)
      if #items==0 then
        logd("bad input",metric_line_)
        return nil
      end

      if type=="command" then
        return command(items)
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

  local function update_sequences(max_)
    -- we now update the real sequences
    local now = time_now()
    local sorted_updated_names = _db.sort_updated_names(keys(_updated_sequences))
    local s = 1
    local e = #sorted_updated_names
    if e==0 then
      --logd("no update required")
      return
    end
    logi("update_sequences start")
    -- why bother with randomness? to avoid starvation
    if max_ and e>max_ then
      s = math.random(e-max_)
      e = s+max_
    end

    for i =s,e do
      local n = sorted_updated_names[i]
      local seq = sequence(_db,n)
      local s = _updated_sequences[n]
      for j,sl in ipairs(s.slots()) do
        local adjusted_timestamp,sum = seq.update(sl._timestamp,sl._sum,sl._hits or 1,
                                                  sl._hits==nil)
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
      _updated_sequences[n] = nil
    end
    logi("update_sequences end",time_now()-now,s,e,#sorted_updated_names)
  end

  local function process(data_,dont_update_)
    -- strings are handled as file pointers if they exist or as a line
    -- tables as arrays of lines
    -- functions as iterators of lines
    local function helper()
      if type(data_)=="string" then
        local file_exists = with_file(data_,
                                      function(f)
                                        for l in f:lines() do
                                          process_line(l)
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
        end
        return rv
      end

      -- we assume it is a function
      local rv
      local count = 0
      for d in data_ do
        rv = process_line(d)
        count = count + 1
        if 0==(count % PROGRESS_AMOUNT) then
          logd("process progress",count)
        end
      end
      return rv
    end


    local rv = helper()
    if not dont_update_ then
      update_sequences()
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
    matching_sequences = matching_sequences,
    get_factories = function() return _factories end,
    reset = reset,
    dump = dump,
    graph = graph,
    key = key,
    piechart = piechart,
    gc = gc,
    latest = latest,
    slot = slot,
    modify_factories = modify_factories,
    process = process,
    update = update_sequences,
    save = save,
    load = load,
    alert_set = alert_set,
    alert_remove = alert_remove,
    alert = alert
  }
end

--verbose_log(true)