
function in_memory_store(key_)
  local _slots = {}
  local _step,_period

  local function reset()
	for i = 1,_period/_step do
	  _slots[i] = {
		_timestamp = 0,
		_hits = 0,
		_sum = 0,
	  }
	end
  end


  local function init(step_,period_)
	_step = step_
	_period = period_
  end

  return {
	create = function(key_,step_,period_) 
			   if not step_ or step_==0 then return nil end
			   init(step_,period_)
			   reset()
			 end,

	load = init,

	reset = reset,
	get_slot = function(idx_)
				 if idx_==0 then idx_ = _size end
				 return _slots[idx_]
			   end,

	set_slot = function(idx_,slot_)
				 if idx_==0 then idx_ = _size end
				 _slots[idx_] = slot_
			   end,

	size = function()
			 return _period/_step
		   end,

	latest = function()
			   return max_timestamp(_period/_step,function(idx_)
													return _slots[idx_]
												  end)
			 end,

	slots = function () return shallow_clone_array(_slots) end,

  }
end

function in_memory_sequences(store_factory_)
  local _seqs = {}

  local function serialize(out_stream_)
	return serialize_table_of_arrays(out_stream_,_seqs,function(out_stream_,item_)
														 item_.serialize(out_stream_)
													   end)
  end

  local function deserialize(in_stream_)
	_seqs = deserialize_table_of_arrays(in_stream_,
										function(in_)
										  local seq = sequence()
										  seq.deserialize(in_,store_factory_)
										  return seq
										end)
  end

  return {
	add = function(metric_,step_,period_)
			local seq = sequence(metric_)
			local store = store_factory_()
			store.create(metric_,step_,period_)
			seq.init(step_,period_,store)
			_seqs[metric_] = _seqs[metric_] or {}
			table.insert(_seqs[metric_],seq)
			return seq
		  end,
	get = function(metric_)
			return _seqs[metric_]
		  end,
	
	keys = function(metric_)
			 local keys = {}
			 for k,_ in pairs(_seqs) do
			   if not metric_ or is_prefix(k,metric_) then
				 table.insert(keys,k)
			   end
			 end

			 return keys
		   end,

	pairs = function(metric_)
			  return coroutine.wrap(function()
									  for k,items in pairs(_seqs) do
										if not metric_ or is_prefix(k,metric_) then
										  for _,s in ipairs(items) do
											coroutine.yield(s)
										  end
										end
									  end
									end)
			end,
	serialize = serialize,
	deserialize = deserialize,
  }

end

