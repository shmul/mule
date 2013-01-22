require "helpers"
local pp = require "purepack"
require "conf"

local function name(metric_,step_,period_)
      return string.format("%s;%s:%s",metric_,
                           secs_to_time_unit(step_),
                           secs_to_time_unit(period_))
end


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

  local function get_slot(idx_)
    return at(idx_)
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
  _seq_storage = db_.sequence_storage(name_,_period/_step)


  local function update(timestamp_,sum_,hits_,replace_)
    local idx,adjusted_timestamp = calculate_idx(timestamp_,_step,_period)
    -- if this value is way back (but still fits in this slot)
    -- we discard it

    if adjusted_timestamp<get_timestamp(idx) then
      return
    end
    -- we need to check whether we should update the current slot
    -- or if are way ahead of the previous time the slot was updated
    -- over-write its value
    local timestamp,hits,sum = get_slot(idx)
    if replace_ or (adjusted_timestamp==timestamp and hits>0) then
      -- no need to worry about the latest here, as we have the same (adjusted) timestamp
      set_slot(idx,adjusted_timestamp,hits+(hits_ or 1),sum+sum_)
    else
      set_slot(idx,adjusted_timestamp,hits_ or 1,sum_)
      if adjusted_timestamp>latest_timestamp() then
        latest(idx)
      end
    end

    _seq_storage.save(_name)
  end

  local function indices(sorted_)
    -- the sorted list is of indices to the main one
	local array = {}
	for i=1,(_period/_step) do
      array[i] = i-1
    end
    if sorted_ then
      table.sort(array,
                 function(u,v)
                   return get_timestamp(u)<get_timestamp(v)
                 end)
    end

	return array
  end

  local function serialize(opts_,metric_cb_,slot_cb_)

    local function serialize_slot(idx_,skip_empty_,slot_cb_)
      local timestamp,hits,sum = get_slot(idx_)
      if not skip_empty_ or sum~=0 or hits~=0 or timestamp~=0 then
        slot_cb_(sum,hits,timestamp)
      end
    end

    opts_ = opts_ or {}
    metric_cb_(_metric,_step,_period)


    local function one_slot(ts_)
      local idx,_ = calculate_idx(ts_,_step,_period)
      if ts_-get_timestamp(idx)<_period then
        serialize_slot(idx,nil,slot_cb_)
      end
    end

    local ind = indices(opts_.sorted)

    if opts_.deep then
      local min_timestamp = nil
      if opts_.period_only then
        min_timestamp = latest_timestamp()-_period
      end
      for _,s in ipairs(ind) do
        if not min_timestamp or min_timestamp<get_timestamp(s) then
          serialize_slot(s,opts_.skip_empty,slot_cb_)
        end
      end
      return
    end

    if opts_.timestamps then
      for _,t in ipairs(opts_.timestamps) do
        if t=="*" then
          for _,s in ipairs(ind) do
            serialize_slot(s,nil,slot_cb_)
          end
        else
          local ts = to_timestamp(t,os.time(),latest_timestamp())
          if ts then
            if type(ts)=="number" then
              one_slot(ts)
            else
              for t = ts[1],ts[2],(ts[1]<ts[2] and _step or -_step) do
                one_slot(t)
              end
            end
          end
        end
      end
    end
  end

  local function slot(idx_)
    local ts,h,s = get_slot(idx_)
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
    latest = latest,
    reset = reset,
    serialize = serialize,
         }
end

-- sparse sequences are expected to have very few (usually one) non empty slots, so we use
-- a plain (non sorted) array

function sparse_sequence(name_)
  local _metric,_step,_period,_name
  local _slots = {}

  _name = name_

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

  local function update(timestamp_,sum_,hits_)
    local _,adjusted_timestamp = calculate_idx(timestamp_,_step,_period)
    -- here, unlike the regular sequence, we keep all the timestamps. The real sequence
    -- will discard stale ones
    local slot = find_slot(adjusted_timestamp)
    slot._sum = slot._sum+sum_
    slot._hits = slot._hits+hits_
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

function one_level_childs(db_,name_)
  return coroutine.wrap(
    function()
      local prefix,rp = string.match(name_,"(.-);(.+)")
      if not prefix or not rp then return end
      local step,period = parse_time_pair(rp)
      local find = string.find
      for name in db_.matching_keys(prefix) do
        if name~=name_ and find(name,rp,1,true) and not find(name,".",#prefix+2,true) then
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
          if not find(name,".",#name_+2,true) then
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
            concat_arrays(metric_rps,rps)
          end
        end
        for m in metric_hierarchy(metric_) do
          for _,rp in ipairs(metric_rps) do
            coroutine.yield(name(m,rp[1],rp[2]))
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
                    if seq.get_timestamp(slot.latest())<timestamp then
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
	local str = stdout("")
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
  end



  local function graph(resource_,options_)
	local str = strout("")
    options_ = options_ or {}
	local timestamps = options_.timestamp and split(options_.timestamp,',') or nil
    local format = string.format
    local col = collectionout(str,"{","}")
	local opts = { deep=not timestamps,
				   timestamps=timestamps,
				   sorted=false,
				   skip_empty=true,
				   period_only=true}
    local depth = is_true(options_.deep) and one_level_childs or immediate_metrics

    col.head()
	for m in split_helper(resource_,"/") do
      for seq in depth(db_,m) do
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

  local function latest(resource_,options_)
    return slot(resource_,{timestamp="latest"})
  end


  local function key(resource_,options_)

	local str = strout("")
    local format = string.format
    local find = string.find
    local col = collectionout(str,"[","]")
    col.head()
	for m in split_helper(resource_ or "","/") do
      m = (m=="*" and "") or m
	  for k in _db.matching_keys(m) do
        if not find(k,"metadata=",1,true) then
          col.elem(format("\"%s\"",k))
        end
	  end
	end
    col.tail()
	return wrap_json(str)
  end

  local function alert_set(resource_,options_)

    _alerts[resource_] = {
      _critical_low = to_number(options_.critical_low),
      _warning_low = tonumber(options_.warning_low),
      _warning_high = tonumber(options_.warning_high),
      _critical_high = tonumber(options_.critical_high),
      _stale = parse_time_unit(options_.stale),
      _sum = 0,
      _latest = 0,
      _state = ""
    }
    logi("set alert",t2s(_alerts[resource_]))
    return ""
  end

  local function alert_remove(resource_)
    if not _alerts[resource_] then
      logw("alert not found",resource_)
      return nil
    end

    _alerts[resource_] = nil
    logi("remove alert",resource_)
    return ""
  end

  local function alert(resource_)
    local str = strout("","\n")
    local format = string.format
    local col = collectionout(str,"{","}")
    local now = os.time()
    col.head()
    local as = _alerts

    if #resource_==0 then
      as = {}
      as[resource_] = _alerts[resource_]
    end

    for n,a in ipairs(as) do
      alert_check_stale(n,now)
      col.elem(format("\"%s\": [%d,%d,%d,%d,%d,%d,\"%s\"]",
                     n,a._critical_low,a._warning_low,a._warning_high,a._critical_high,
                     a._stale,a._sum,a._state))
    end
    col.tail()

 	return wrap_json(str)
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
                           stale = items_[7],
                                   })
      end,
      latest = function()
        return latest(items_[2])
      end,
      slot = function()
        return slot(items_[2],{timestamp=items_[3]})
      end,
      gc = function()
        return gc(items_[2],{timestamp=items_[3],force=TRUTH(items_[4])})
      end,
      reset = function()
        return reset(items_[2])
      end,
      dump = function()
        return dump(items_[2])
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
  end


  local function save()
    logi("save",table_size(_factories))
    _db.put("metadata=version",pp.pack(CURRENT_VERSION))
    _db.put("metadata=factories",pp.pack(_factories))
    _db.put("metadata=alerts",pp.pack(_alerts))
  end


  local function load()
    logi("load")
    local ver = _db.get("metadata=version")
    local factories = _db.get("metadata=factories")
    local alerts = _db.get("metadata=alerts")
	local version = ver and pp.unpack(ver) or CURRENT_VERSION
	if not version==CURRENT_VERSION then
	  error("unknown version")
	  return nil
	end
	_factories = factories and pp.unpack(factories) or {}
	_alerts = alerts and pp.unpack(alerts) or {}
  end


  local function alert_check_stale(name_,timestamp_)
    local alert = _alerts[name_]
    if not alert then
      return nil
    end
    if alert._latest+alert._stale<timestamp_ then
      alert._state = "stale"
      return true
    end
    return false
  end

  local function check_alert(sequence_,timestamp_)
    local alert = _alerts[sequence_.name()]
    if not alert then
      return nil
    end

    alert._latest = sequence_.get_timestamp(sequence_.latest())
    if alert_check_stale(sequence_.name()) then
      return alert
    end

    local average_sum = 0
    for ts = timestamp_-alert._period,timestamp_,sequence_.step() do
      local slot = sequence_.slot(sequence_.slot_index(ts))
      average_sum = average_sum + (slot._sum*(ts-slot._timestamp)/sequence_.step())
    end

    alert._sum = average_sum
    alert._state = (average_sum<alert._critical_low and "CRITICAL low") or
      (average_sum<alert._warning_low and "WARNING low") or
      (average_sum>alert._warning_high and "WARNING high") or
      (average_sum>alert._critical_high and "CRITICAL high") or "normal"
    return alert
  end

  local function update_line(metric_,sum_,timestamp_,updated_sequences_)
    for n in get_sequences(metric_) do
      local seq = updated_sequences_[n] or sparse_sequence(n)
	  seq.update(timestamp_,sum_,1)
      updated_sequences_[n] = seq
	end
  end


  local function update_sequence(seq_,slots_)
    -- slots is a flat array of arrays
    local j = 1
    while j<#slots_ do
      local sum,hits,timestamp = tonumber(slots_[j]),tonumber(slots_[j+1]),tonumber(slots_[j+2])
      j = j + 3
      seq_.update(timestamp,sum,hits)
    end
    return j-1
  end

  local function modify_factories(factories_modifications_)
    -- the factories_modifications_ is a list of triples,
    -- <pattern, original retention, new retention>
    for _,f in ipairs(factories_modifications_) do
      local factory = _factories[f[1]];
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
              local new_seq = sequence(db_,new_name)
              update_sequence(new_seq,seq.slots())
              _db.out(seq.name())
            end
          end
        end
      else
        logw("pattern not found",f[1])
      end
    end
  end

  local function process_line(metric_line_,update_sequences_)
	local items,type = parse_input_line(metric_line_)
	if #items==0 then return nil end

	if type=="command" then
	  return command(items)
	end
	-- there are 2 line formats:
	-- 1) of the format metric sum timestamp
	-- 2) of the format (without the brackets) name (sum hits timestamp)+

	-- 1) standard update
	if not string.find(items[1],";",1,true) then
	  return update_line(items[1],tonumber(items[2]),tonumber(items[3]),update_sequences_)
	end

    -- 2) an entire sequence
    local name = items[1]
    table.remove(items,1)
    -- here we DON'T use the sparse sequence as they aren't needed when reading an
    -- entire sequence
    local seq = sequence(_db,name)
    return update_sequence(seq,items)
  end


  local function process(data_)
    local updated_sequences = {}
	-- strings are handled as file pointers if they exist or as a line
	-- tables as arrays of lines
	-- functions as iterators of lines
    local function helper()
      if type(data_)=="string" then
        local file_exists = with_file(data_,function(f)
                                        for l in f:lines() do
                                          process_line(l,updated_sequences)
                                        end
                                            end)
        if file_exists then
          return true
        end
        return process_line(data_,updated_sequences)
      end

      if type(data_)=="table" then
        local rv
        for _,d in ipairs(data_) do
          rv = process_line(d,updated_sequences)
        end
        return rv
      end

      -- we assume it is a function
      local rv
      local count = 0
      for d in data_ do
        rv = process_line(d,updated_sequences)
        count = count + 1
        if 0==(count % PROGRESS_AMOUNT) then
          logd("process progress",count)
        end
      end
      return rv
    end

    local rv = helper()
    -- we now update the real sequences
    local now = os.time()
    local sorted_updated_names = _db.sort_updated_names(keys(updated_sequences))
    for _,n in ipairs(sorted_updated_names) do
      local seq = sequence(_db,n)
      local s = updated_sequences[n]
      for _,sl in ipairs(s.slots()) do
        seq.update(sl._timestamp,sl._sum,sl._hits)
      end
      check_alert(seq,now)
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
    save = save,
    load = load,
    alert_set = alert_set,
    alert_remove = alert_remove,
    alert = alert
  }
end
