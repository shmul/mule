--TODO
-- support ''not'' patterns
-- save metadata under multiple ''metadata#ABC'' keys and not a single one
require "helpers"

local CURRENT_VERSION = 2




local function update_slot_helper(slot_,timestamp_,value_,hits_,reset_)
  if not reset_ and slot_._hits>0 then
	slot_._hits = slot_._hits+hits_
	slot_._sum = slot_._sum+value_
	return slot_
  end
  return {
	_timestamp = timestamp_,
	_hits = 1,
	_sum = value_
  }
end



function serialize_slot(out_stream_,s,skip_empty_)
  local sum = s and s._sum or 0
  local hits = s and s._hits or 0
  local timestamp = s and s._timestamp or 0
  if not skip_empty_ or sum~=0 or hits~=0 or timestamp~=0 then
	out_stream_.start_of_record()
	out_stream_.write_number(sum)
	out_stream_.write_number(hits)
	out_stream_.write_number(timestamp)
	out_stream_.end_of_record()
  end
end

function sequence(metric_)

  local _metric = metric_
  local _step,_period,_store


  local function find_slot(timestamp_)
	return calculate_slot(timestamp_,_step,_period)
  end

  local function interpolate_timestamp(timestamp_)
	local latest = _store.get_slot(_store.latest())._timestamp
	return to_timestamp(timestamp_,os.time(),latest)
  end

  local function sorted_slots()
	-- we should sort on the timestamp to output the slots in order
	-- no one guarantees continuous output
	-- we must first clone the slots so we won't sort the original sequence
	local slots = _store.slots()
	table.sort(slots,function(u,v)
					   return not u._timestamp or (u._timestamp<v._timestamp)
					 end)
	return slots
  end

  local function get(timestamp_)
	local idx,adjusted_timestamp = find_slot(timestamp_)
	local slot = _store.get_slot(idx)
	-- if this value is way back (but still fits in this slot) OR
	-- if it is way ahead the the previous time the slot was updated
	-- we have nothing to return
	if (slot and adjusted_timestamp<slot._timestamp) or math.abs(adjusted_timestamp-slot._timestamp)>_step then
	  return nil
	end

	return slot
  end


  return {
	init = function(step_,period_,sequence_store_)
			   _step = step_
			   _period = period_
			   _store = sequence_store_
			 end,

	get_metric = function() return _metric end,

	find_slot = find_slot,

	get_slot = function(idx_)
				 return _store.get_slot(idx_)
			   end,

	get = get,

	latest = function()
			   return _store.latest()
			 end,

	update = function(timestamp_,value_,hits_)
			   local idx,adjusted_timestamp = find_slot(timestamp_)
			   local slot = _store.get_slot(idx)
			   -- if this value is way back (but still fits in this slot)
			   -- we discard it
			   if slot and adjusted_timestamp<slot._timestamp then
				 return
			   end
			   -- we need to check whether we should update the current slot
			   -- or if are way ahead of the previous time the slot was updated
			   -- over-write its value
			   local reset = not slot or math.abs(adjusted_timestamp-slot._timestamp)>_step
			   _store.set_slot(idx,update_slot_helper(slot,adjusted_timestamp,
													  value_,hits_,reset))
			 end,


    reset = function()
			  _store.reset()
			end,


	serialize = function(out_stream_,opts_)
				  opts_ = opts_ or {}
				  out_stream_.start_of_header()
				  if not opts_.pretty_print then
					out_stream_.write_string(_metric)
					out_stream_.write_timestamp(_step)
					out_stream_.write_timestamp(_period)
					-- is skip_empty_ is used this might be larger than the actual number
					-- of elements written to the stream
				  else
					out_stream_.write_string(string.format("%s;%s:%s",_metric,
														   secs_to_time_unit(_step),
														   secs_to_time_unit(_period)))
				  end

				  out_stream_.end_of_header()
				  if opts_.deep then
					local min_timestamp = nil
					if opts_.period_only then
					  local latest_idx = _store.latest()
					  local max_timestamp = _store.get_slot(latest_idx)._timestamp
					  min_timestamp = max_timestamp-_period
					end
					local slots = opts_.sorted and sorted_slots() or _store.slots()
					for i,s in ipairs(slots) do
					  if not min_timestamp or min_timestamp<s._timestamp then
						serialize_slot(out_stream_,s,opts_.skip_empty)
					  end
					end

				  elseif opts_.timestamps then
					local function one_slot(ts_)
					  local idx,_ = find_slot(ts_)
					  local slot = _store.get_slot(idx)
					  if ts_-slot._timestamp<_period then
						serialize_slot(out_stream_,slot)
					  end
					end

					for _,t in ipairs(opts_.timestamps) do
					  local ts = interpolate_timestamp(t)
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

				  elseif opts_.latest then
					serialize_slot(out_stream_,_store.get_slot(_store.latest()))
				  end
				end,

	deserialize = function(in_stream_,sequence_store_factory_,deep_)
					_metric = in_stream_.read_string()
					if not _metric or #_metric==0 then return nil end
					_step = in_stream_.read_timestamp()
					_period = in_stream_.read_timestamp()
					_store = sequence_store_factory_()
					_store.load(_metric,_step,_period)
					if deep_ then
					  for i=1,_period/_step  do
						local s = {
						  _sum = in_stream_.read_number(),
						  _hits = in_stream_.read_number(),
						  _timestamp = in_stream_.read_timestamp(),
						}
						_store.set_slot(i,s)
					  end
					end
					return _metric
				  end,
  }


end





function parse_input_line(line_)
  local items = nil
  if string.sub(line_,1,1)=='.' then
	-- command
	items = split(line_,' ')
	items[1] = string.sub(items[1],2)
	return items,"command"
  end
  -- metrics
  items = split(line_,' ')
  return items
end

function metric_hierarchy(metric_)
  return coroutine.wrap(function()
						  local current = ""
						  for i,p in ipairs(split(metric_,'.')) do
							current = i==1 and p or string.format("%s.%s",current,p)
							coroutine.yield(current)
						  end
						end)
end


function metric_one_level_childs(sequences_,metric_)
  local m,ts = string.match(metric_,"(.-);(.+)")

  return coroutine.wrap(function()
						  if not m then return end
						  for child in sequences_.keys(m) do
							local cm,cts = string.match(child,"(.-);(.+)")
							-- we are intersted only in child metrics of the format
							-- m.sub-key;ts where sub-key contains no dots
							local i = string.find(cm,m,1,true)
							if i==1 and cts==ts and m~=cm and not string.find(cm,".",#m+2,true) then
							  coroutine.yield(child)
							end
						  end
						end
					   )
end


function mule(sequences_)
  local _factories = {}
  local _sequences = sequences_

  local function add_factory(pattern_,retentions_)
	local pattern = string.match(pattern_,"^(.-)%.*$")
	for _,rp in ipairs(retentions_) do
	  local step,period = parse_time_pair(rp)
	  if step and period then
		if step>period then
		  loge("step greater than period",rp,step,period)
		  error("step greater than period")
		  return nil
		end
		
		_factories[pattern] = _factories[pattern] or {}
		table.insert(_factories[pattern],{step,period})
	  end
	end
	return true
  end

  local function matching_sequences(metric_)
	local matches = {}
	if metric_=="*" then
	  for s in _sequences.pairs() do
		table.insert(matches,s)
	  end
	else
	  for m in metric_hierarchy(metric_) do
		local seqs = _sequences.get(m)
		if seqs then
		  concat_arrays(matches,seqs)
		end
	  end
	end
	return matches
  end


  local function factory(metric_)
	local function matching_sequences_not_inited(metric_,prefix_)
	  return coroutine.wrap(function()
							  for m in metric_hierarchy(metric_) do
								if not _sequences.get(m) and is_prefix(m,prefix_) then
								  coroutine.yield(m)
								end
							  end
							end)

	end

	local matches = {}
	for pattern,rps in pairs(_factories) do
	  for m in matching_sequences_not_inited(metric_,pattern) do
		for _,rp in ipairs(rps) do
		  if rp[1]~=0 and rp[2]~=0 then
			matches[#matches+1] = _sequences.add(m,rp[1],rp[2])
		  end
		end
	  end
	end
	return matches
  end

  local function gc(metric_,timestamp_,dry_run_)
	local garbage = {}

	for seq in _sequences.pairs(metric_) do
	  local garbage = {}
      local str = jsonout(false)
	  if seq.latest()<timestamp_ then
		str.start_of_header()
		str.write_string(seq.get_metric())
		str.end_of_header()
		garbage[#garbage+1] = seq
	  end
	end

    if not dry_run_ then
      for _,metric in ipairs(garbage) do
        _sequences.out(metric)
      end
    end

 	return wrap_json(str,"mule_gc")
  end

  local function reset(metric_)
	for s in _sequences.pairs(metric_) do
	  s.reset()
	end
	return true
  end

  local function dump(metrics_)
	local str = stdout(" "," ")
	for m in split_helper(metrics_,"/") do
	  for seq in _sequences.pairs(m) do
		seq.serialize(str,{deep=true,skip_empty=true,pretty_print=true})
		str.write_string("\n")
	  end
	end
  end

  local function wrap_json(stream_,javascript_callback_)
	stream_.close()
	local str = stream_.get_string()
	if #str==0 then return nil end
	return string.format("%s({\"version\": %d,\n\"data\": %s\n})",javascript_callback_,
						 CURRENT_VERSION,
						 #str>0 and str or '""')
  end

  local function graph(metrics_,timestamps_)
	local str = jsonout(true)
	local timestamps = timestamps_ and split(timestamps_,',') or nil

	local opts = { deep=not timestamps,
				   timestamps = timestamps,
				   sorted=false,
				   skip_empty=true,
				   pretty_print=true,
				   period_only=true}
	for m in split_helper(metrics_,"/") do
	  for seq in _sequences.pairs(m) do
		seq.serialize(str,opts)
	  end
	end
	return wrap_json(str,"mule_graph")
  end

  local function piechart(metrics_,timestamps_)
	local str = jsonout(true)
	local timestamps = timestamps_ and split(timestamps_,',') or nil

	local opts = { deep=false,
				   timestamps = timestamps,
				   sorted=false,
				   skip_empty=true,
				   pretty_print=true,
				   period_only=true}

	for m in split_helper(metrics_,"/") do
	  for k in metric_one_level_childs(_sequences,m) do
		for seq in _sequences.pairs(k) do
		  seq.serialize(str,opts)
		end
	  end
	end
	return wrap_json(str,"mule_graph")
  end

  local function latest_helper(metrics_,flag_,wrapper_)
	local str = jsonout(true)
	local flags = {pretty_print=true}
	flags[flag_] = true

	for m in split_helper(metrics_,"/") do
	  for seq in _sequences.pairs(m) do
		seq.serialize(str,flags)
	  end
	end
	return wrap_json(str,wrapper_)
  end

  local function latest(metrics_)
	return latest_helper(metrics_,"latest","mule_latest")
  end


  local function slot(metrics_,timestamp_)
	local str = jsonout(true)
	for m in split_helper(metrics_,"/") do
	  local l = latest(m)
	  for seq in _sequences.pairs(m) do
		seq.serialize(str,{pretty_print=true,timestamps={to_timestamp(timestamp_,os.time(),l)}})
	  end
	end
	return wrap_json(str,"mule_slot")
  end

  local function keys(metrics_)
	local str = jsonout(false)
	for m in split_helper(metrics_,"/") do
	  for k in _sequences.keys(m) do
		str.start_of_header()
		str.write_string(k)
		str.end_of_header()
	  end
	end
	return wrap_json(str,"mule_keys")
  end



  local function command(items_)
	local dispatch_table = {
	  reset = reset,
	  dump = dump,
	  graph = graph,
	  piechart = piechart,
	  keys = keys,
	  gc = gc,
	  latest = latest,
	  slot = slot
	}

	if dispatch_table[items_[1]] then
	  logi(items_[1],items_[2])
	  return dispatch_table[items_[1]](items_[2],items_[3])
	end

	loge("unknown command",items_[1])
  end

  local function configure(configuration_lines_)
	for l in lines_without_comments(configuration_lines_) do
	  local items,type = parse_input_line(l)
	  if type then
		logw("unexpexted type",type)
	  else
		local pattern = items[1]
		table.remove(items,1)
		add_factory(pattern,items)
	  end
	end

  end

  local function update_line(metric_,value_,timestamp_)
	local matches = matching_sequences(metric_)
	concat_arrays(matches,factory(metric_))
	matches = matches or {}
	if not matches then
	  loge("couldn't find a match for",metric_line_)
	  return "0"
	end
	
	for _,s in ipairs(matches) do
	  s.update(timestamp_,value_,1)
	end
	return tostring(#matches)
  end


  local function update_sequence(seq_,slots_)
	local j = 1
	while j<#slots_ do
	  local sum,hits,timestamp = tonumber(slots_[j]),tonumber(slots_[j+1]),tonumber(slots_[j+2])
	  j = j + 3
	  seq_.update(timestamp,sum,hits)
	end

	return j-1
  end

  local function process_line(metric_line_)
	local items,type = parse_input_line(metric_line_)
	if #items==0 then return nil end

	if type=="command" then
	  return command(items)
	end
	-- there are 2 line formats:
	-- 1) of the format event.phishing.phishing-host 20 74857843
	-- 2) of the format (without the brackets) event.phishing.phishing-host;1h:30d (sum hits timestamp)+

	-- 1) standard update
	if not string.find(items[1],";",1,true) then
	  return update_line(items[1],tonumber(items[2]),tonumber(items[3]))
	else
	  -- 2) an entire line
	  local metric = items[1]
	  local seq = _sequences.get(metric)
	  table.remove(items,1)
	  if not seq then
		local metric_name,time_pair = string.match(metric,"(.-);(.+)")
		local step,period = parse_time_pair(time_pair)
		seq = {_sequences.add(metric_name,step,period)}
	  end
	  return update_sequence(seq[1],items)
	end
  end

  local function serialize(out_)
	if not _factories then return nil end
	out_.write_number(CURRENT_VERSION)

	serialize_table_of_arrays(out_,_factories,function(out_,item_)
												out_.write_number(item_[1])
												out_.write_number(item_[2])
											  end)

	_sequences.serialize(out_)
  end


  local function deserialize(in_stream_)
	local version = in_stream_.read_number()
	if not version==CURRENT_VERSION then
	  error("unknown version")
	  return nil
	end

	_factories = deserialize_table_of_arrays(in_stream_,function(in_)
														  return {in_.read_number(),
																  in_.read_number()}
														end)
	_sequences.deserialize(in_stream_)

  end


  local function process(data_)
	-- strings are handled as file pointers if they exist or as a line
	-- tables as arrays of lines
	-- functions as iterators of lines
	if type(data_)=="string" then
	  local file_exists = with_file(data_,function(f)
											for l in f:lines() do
											  process_line(l)
											end
										  end)
	  if file_exists then
		return true
	  end
	  return process_line(data_)
	elseif type(data_)=="table" then
	  local rv
	  for _,d in ipairs(data_) do
		rv = process_line(d)
	  end
	  return rv
	elseif type(data_)=="function" then
	  local rv
	  for d in data_ do
		rv = process_line(d)
	  end
	  return rv
	end

  end


  return {
	configure = configure,
	factory = factory,
	matching_sequences = matching_sequences,
	get_factories = function() return _factories end,
	get_sequences = function() return _sequences end,
	serialize = serialize,
	deserialize = deserialize,
	reset = reset,
	dump = dump,
	graph = graph,
	piechart = piechart,
	gc = gc,
	latest = latest,
	slot = slot,
	process = process
  }
end

