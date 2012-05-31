
tokyo = require "tokyocabinet" 

if not tokyo then
  return
end

function generate_fuctions()
  local db

  return 
    function(database_)
	-- we use this either to open a file, or to set the db value to an externally
	-- opened db
	if type(database_)=="string" then
	  db = tokyocabinet.bdbnew()
	  if not db:open(database_,db.OWRITER+db.OCREAT) then
		local ecode = db:ecode()
		local errmsg = db:errmsg(ecode)
		logf("unable to open db",database_,ecode,errmsg)
		return nil,errmsg
	  end
	else
	  db = database_
	end
	return db
    end,
    function() db:close() end,
    function(k) return db:get(k) end,
    function(k,v) return db:put(k,v) end,
    function(k) return db:fwmkeys(k) end,
    tokyocabinet.pack,
    tokyocabinet.unpack,
    function(k) return db:out(k) end
end



local function tokyocabinet_sequence_name(metric_,step_,period_)
  if not step_ or not period_ then return metric_ end
  return string.format("%s;%s:%s",metric_,secs_to_time_unit(step_),
					   secs_to_time_unit(period_))
end

local function tokyocabinet_key(sequence_name_)
  return string.format("%s;metadata",sequence_name_)
end

local function tokyocabinet_metric_from_metadata_key(metadata_)
  return string.match(metadata_,"([^;]+)")
end

function tokyocabinet_store(db_)
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack,tc_out = generate_fuctions()
  local _size = 0
  local _step,_period,_latest,_key,_seq_name,_seq_metadata

  tc_init(db_)
  
  local function set_names(key_)
	_key = key_
	_seq_name = tokyocabinet_sequence_name(_key,_step,_period)
	_seq_metadata = tokyocabinet_key(_seq_name)
  end
  
  local function load_metadata(key_metadata_)
	local md = tc_get(key_metadata_)
	if not md then return nil end
	_step,_period,_latest = unpack(tc_unpack("NNN",md))
	local key = tokyocabinet_metric_from_metadata_key(key_metadata_)
	set_names(key)
	_size = _period/_step
  end

  local function save_metadata()
	set_names(_key)
	tc_put(_seq_metadata,tc_pack("NNN",_step,_period,_latest))
  end

  local function new_sequence()
	-- we create a packed string for all the slots
	logi("new_sequence",_seq_name,_size)
	local slots = {}
	for i=1,_size*3 do
	  slots[i] = 0
	end
	return tc_pack(string.rep("NNN",_size),slots)
  end

  local function create(key_,step_,period_)
	_key = key_
	_size = period_/step_
	_step = step_
	_period = period_
	_latest = 0
	save_metadata()
	if not tc_get(_seq_name) then
	  local ns = new_sequence()
	  tc_put(_seq_name,ns)
	end
  end

  local function unpack_slot(seq_,idx_)
	local slot = tc_unpack("NNN",string.sub(seq_,(idx_-1)*12+1,idx_*12))
	return {
	  _timestamp = slot[1],
	  _hits = slot[2],
	  _sum = slot[3]
           }
  end

  local function get(idx_)
	if idx_==0 then idx_ = _size end
	return unpack_slot(tc_get(_seq_name),idx_)
  end

  local function put(idx_,slot_)
	if idx_==0 then idx_ = _size end
	local seq = tc_get(_seq_name)
	local slot = tc_pack("NNN",slot_._timestamp,slot_._hits,slot_._sum)
	local prefix = string.sub(seq,1,(idx_-1)*12)
	local suffix = string.sub(seq,1+(idx_*12))
	local updated_seq = table.concat({prefix,slot,suffix})
	tc_put(_seq_name,updated_seq)
	_latest = idx_
  end

  local function slots()
	local seq = tc_get(_seq_name)
	local slots = tokyocabinet.tablenew(_size) -- preallocation
	for i=1,_size do
	  slots[i] = unpack_slot(seq,i)
	end
	return slots
  end

  local function reset()
	local ns = new_sequence()
	tc_put(_seq_name,ns)
  end

  return {
	create = create,
	load = load_metadata,
	reset = reset,
	get_slot = get,
	set_slot = put,
    out = tc_out,
	size = function() return _size end,
	step = function() return _step end,
	period = function() return _period end,
	latest = function()
      return max_timestamp(_size,function(idx_)
                             return get(idx_)
                                 end)
    end,

	slots = slots
         }
end

function tokyocabinet_sequences(store_factory_,tc_get,tc_fwmkeys)

  local function create_sequence(metadata_key_)
	-- k is of the form ''metric;step:period;metadata''
	local store = store_factory_()
	store.load(metadata_key_)
	local seq = sequence(tokyocabinet_metric_from_metadata_key(metadata_key_))
	seq.init(store.step(),store.period(),store)
	return seq
  end

  return {
	add = function(metric_,step_,period_)
      local seq = sequence(metric_)
      local store = store_factory_()
      store.create(metric_,step_,period_)
      seq.init(step_,period_,store)
      return seq
    end,
	
	get = function(metric_)
      local keys = tc_fwmkeys(metric_..";") -- we want the specific metrics, not the decendents
      local seqs = {}
      for _,k in ipairs(keys) do
        if string.find(k,";metadata",1,true) then
          local seq = create_sequence(k)
          table.insert(seqs,seq)
        end
      end
      return #seqs>0 and seqs
    end,

	out = function(metric_)
      store.out(metric_)
    end,

	keys = function(metric_)
      local keys = tc_fwmkeys((not metric_ or metric_=="*") and "" or metric_)
      local find = string.find
      return coroutine.wrap(function()
                              for _,k in ipairs(keys)  do
                                if 1~=find(k,"metrics;",1,true) and not find(k,";metadata",1,true) then
                                  coroutine.yield(k)
                                end
                              end
                            end)
    end,

	
	pairs = function(metric_)
      local keys = tc_fwmkeys((not metric_ or metric_=="*") and "" or metric_)
      local find = string.find
      return coroutine.wrap(function()
                              for _,k in ipairs(keys)  do
                                if 1~=find(k,"metrics;",1,true) and find(k,";metadata",1,true) then
                                  coroutine.yield(create_sequence(k))
                                end
                              end
                            end)
    end,
	-- no need for serialize/deserialize on tokyo as it is already
	-- supported via the keys iteration and put
	serialize = function() end,
	deserialize = function() end,
         }

end

function tc_mule()

  local _mule = {}
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()

  local function open_db(db_path_)
	local db = tc_init(db_path_)
	local abstract_mule = mule(tokyocabinet_sequences(
                                 function(metric_,step_,period_)
                                   return tokyocabinet_store(db,metric_,step_,period_)
                                 end,tc_get,tc_fwmkeys ))
	copy_table(abstract_mule,_mule)
  end
  _mule.config_file = function(config_file_)
    with_file(config_file_,
              function(f)
                _mule.configure(f:lines())
              end)
  end

  _mule.create = function(db_path_)
    open_db(db_path_)
  end
  _mule.load = function(db_path_,readonly_)
    open_db(db_path_)
    if not readonly_ then
      local config = tc_get("metrics;metadata")
      if config then
        _mule.deserialize(strin(config))
      end
    end
  end
  _mule.save = function()
    local config = strout()
    if config then
      _mule.serialize(config)
      tc_put("metrics;metadata",config.get_string())
    end
  end
  
  _mule.close = function()
    tc_done()
    _mule = nil
  end

  return _mule
end
