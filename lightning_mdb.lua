module("lightning_mdb",package.seeall)
local lightningmdb_lib= require("lightningmdb")
local pp = require("purepack")
require "helpers"


local lightningmdb = _VERSION=="Lua 5.2" and lightningmdb_lib or lightningmdb

local NUM_PAGES = 25600
local MAX_SLOTS_IN_SPARSE_SEQ = 10
local SLOTS_PER_PAGE = 16
local MAX_CACHE_SIZE = 200
function lightning_mdb(base_dir_,read_only_,num_pages_,slots_per_page_)
  local _meta,_meta_db
  local _envs = {}
  local _slots_per_page
  local _cache = {}
  local _caches_size = 0
  local _nodes_cache = {}

  local function txn(env_,func_)
    local t = env_:txn_begin(nil,0)
    local rv,err = func_(t)
    if err then
      t:abort()
      return nil,err
    end
    t:commit()
    return rv,err
  end

  local function new_env_factory(name_)
    local e = lightningmdb.env_create()
    local full_path = base_dir_.."/"..name_
    local r,err = e:set_mapsize((num_pages_ or NUM_PAGES)*4096)
    os.execute("mkdir -p "..full_path)
    e:open(full_path,read_only_ and lightningmdb.MDB_RDONLY or 0,420)
    logi("new_env_factory",full_path)
    return e
  end

  local function new_db(env_)
    return txn(env_,
      function(t)
        local r,err = t:dbi_open(nil,read_only_ and 0 or lightningmdb.MDB_CREATE)
        if err then
          loge("new_db",err)
        end
        return r
      end)
  end

  local function add_env()
    local e = new_env_factory(tostring(#_envs))
    logi("creating new env pair",#_envs)
    table.insert(_envs,{e,new_db(e)})
  end


  local function pack_node(node_)
    local seq = node_._seq
    if seq then
      node_._slots = seq.slots()
      node_._seq = nil
    end
    local packed = pp.pack(node_)
    node_._seq = seq
    node_._slots = nil
    return packed
  end

  local function unpack_node(name_,data_)
    if not data_ then
      return nil
    end
    local node = pp.unpack(data_)
    if not node then
      return nil
    end
    if node._slots then
      local seq = sparse_sequence(name_,node._slots)
      node._slots = nil
      node._seq = seq
    end
    return node
  end

  local function put_helper(k,v)
    if string.find(k,"metadata=",1,true) then
      return _meta and txn(_meta,function(t) return t:put(_meta_db,k,v,0) end)
    end
    return txn(_envs[#_envs][1],
               function(t)
                 local rv,err = t:put(_envs[#_envs][2],k,v,0)
                 if not err then return true end
                 add_env()
                 return put_helper(k,v)
               end)
  end

  local function put(k,v,dont_cache_)
    if dont_cache_ then
      return put_helper(k,v)
    end
    _cache[k] = v
    return _cache[k]
  end

  local function put_node(k,node)
    _nodes_cache[k] = node
    return _nodes_cache[k]
  end

  local function flush_cache()
    local count,nodes = 0,0
    logi("flush_cache start")
    for k,v in pairs(_cache) do
      put_helper(k,pp.pack(v))
      count = count + 1
    end
    for k,v in pairs(_nodes_cache) do
      put_helper(k,pack_node(v))
      nodes = nodes + 1
    end
    logi("flush_cache",_caches_size,count,nodes)
    _cache = {}
    _nodes_cache = {}
    _caches_size = 0
  end

  local function get_helper(k)
    if string.find(k,"metadata=",1,true) then
      return txn(_meta,function(t) return t:get(_meta_db,k) end)
    end

    for _,ed in ipairs(_envs) do
      local rv,err = txn(ed[1],function(t) return t:get(ed[2],k) end)
      if not err then return rv end
    end
  end

  local function get(k,dont_cache_)
    if _caches_size>=MAX_CACHE_SIZE then
      flush_cache()
    end
    if dont_cache_ then
      return get_helper(k)
    end
    if not _cache[k] then
      _cache[k] = pp.unpack(get_helper(k))
      if _cache[k] then
        _caches_size = _caches_size + 1
      end
    end
    return _cache[k]
  end

  local function get_node(k)
    if not _nodes_cache[k] then
      _caches_size = _caches_size + 1
      _nodes_cache[k] = unpack_node(k,get_helper(k))
      if _nodes_cache[k] then
        _caches_size = _caches_size + 1
      end
    end
    return _nodes_cache[k]
  end


  local function init()
    _meta = new_env_factory("meta")
    _meta_db = new_db(_meta)
    add_env()
    _slots_per_page = get("metadata=slots_per_page")
    if not _slots_per_page then
     _slots_per_page = slots_per_page_ or SLOTS_PER_PAGE
      put("metadata=slots_per_page",_slots_per_page)
    end
  end


  local function del(k)
    _cache[k] = nil
    _nodes_cache[k] = nil
    if string.find(k,"metadata=",1,true) then
      return txn(_meta,function(t) return t:del(_meta_db,k,nil) end)
    end

    for _,ed in ipairs(_envs) do
      local rv,err = txn(ed[1],function(t) return t:del(ed[2],k,nil) end)
    end
  end

  local function search(prefix_)
    flush_cache()
    for _,ed in ipairs(_envs) do
      local t = ed[1]:txn_begin(nil,lightningmdb.MDB_RDONLY)
      local cur = t:cursor_open(ed[2])
      local k,v = cur:get(prefix_,lightningmdb.MDB_SET_RANGE)
      cur:close()
      t:commit()
      if k then
        return k,v
      end
    end
  end

  local function page_key(name_,idx_)
    -- no sparse seq? then we should find the page
    local p = math.floor(idx_/_slots_per_page)
    local q = idx_%_slots_per_page
    return string.format("%04d|%s",p,name_),p,q
  end

  local function internal_get_slot(name_,idx_,offset_)
    local function no_data()
      if offset_ then return 0 end
      return 0,0,0
    end
    -- the name is used as a key for the metadata
    local node = get_node(name_)
    if not node then
      return no_data()
    end

    -- trying to access one past the cdb size is interpreted as
    -- getting the latest index
    if node._size==idx_ then
      return node._latest
    end

    if node._seq then
      local slot = node._seq.find_by_index(idx_)
      if not slot then
        return no_data()
      end
      if not offset_ then
        return slot._timestamp,slot._hits,slot._sum
      end
      return (offset_==0 and slot._timestamp) or (offset_==1 and slot._hits) or (offset_==2 and slot._sum)
    end

    local key,p,q = page_key(name_,idx_)
    local page_data = get(key)
    if page_data then
      return get_slot(page_data,q,offset_)
    end
    return no_data()
  end

  local function internal_set_slot(name_,idx_,offset_,timestamp_,hits_,sum_)
    local function new_page_data()
      return string.rep(string.char(0),pp.PNS*3*_slots_per_page)
    end

    -- the name is used as a key for the metadata
    local node = get_node(name_)
    if not node then
      -- a new node keeps a sparse_sequence instead of allocating actual pages for the slots
      local _,step,period = split_name(name_)
      node = { _latest = 0, _seq = sparse_sequence(name_), _size = period/step }
    end

    -- trying to access one past the cdb size is interpreted as
    -- getting the latest index
    if node._size==idx_ then
      node._latest = timestamp_ -- this is actually the index of the latest slots
      put_node(name_,node)
      return
    end

    if node._seq then
      node._seq.set(timestamp_,hits_,sum_)
      if #node._seq.slots()==MAX_SLOTS_IN_SPARSE_SEQ then
        -- time to create actual pages
        local slots = node._seq.slots()
        logi("lightningmdb creating pages",name_)
        local _,step,period = split_name(name_)
        node._seq = nil
        for _,s in ipairs(slots) do
          local i,_ = calculate_idx(s._timestamp,step,period)
          local key,p,q = page_key(name_,i)
          local page_data = get(key) or new_page_data()
          local t,u,v = set_slot(page_data,q,offset_,s._timestamp,s._hits,s._sum)
          put(key,pp.concat_three_strings(t,u,v))
        end
      end
      put_node(name_,node)
      return
    end

    local key,p,q = page_key(name_,idx_)
    local page_data = get(key) or new_page_data()

    local t,u,v = set_slot(page_data,q,offset_,timestamp_,hits_,sum_)
    page_data = pp.concat_three_strings(t,u,v)
    put(key,page_data)
  end

  local function internal_out_slot(name_)
    local node = get_node(name_)
    if node then
      logi("internal_out_slot - deleting pages",name_)
      for idx=0,node._size-1,_slots_per_page do
        local key,p,q = page_key(name_,idx)
        del(key)
      end
    end
    logi("internal_out_slot - deleting node",name_)
    del(name_)
  end

  local function matching_keys(prefix_,level_,meta_)
    local function helper(env,db)
      local t,err = env:txn_begin(nil,lightningmdb.MDB_RDONLY)
      local find = string.find
      local byte = string.byte

      local cur = t:cursor_open(db)
      local k = cur:get_key(prefix_,lightningmdb.MDB_SET_RANGE)
      -- 124 is ascii for |
      repeat
        local prefixed = k and find(k,prefix_,1,true)
        if k and byte(k,5)~=124 and prefixed and bounded_by_level(k,prefix_,level_) then
          coroutine.yield(k)
        end
        if not prefixed then
          k = nil
        else
          k = cur:get_key(k,lightningmdb.MDB_NEXT)
        end
      until not k
      cur:close()
      t:commit()
    end
    return coroutine.wrap(function()
                            flush_cache()
                            if meta_ then
                              helper(_meta,_meta_db)
                              return
                            end
                            for _,ed in ipairs(_envs) do
                              helper(ed[1],ed[2])
                            end
                            flush_cache()
                          end)
  end



  local function close()
    logi("lightning_mdb close")
    flush_cache()
    if _meta then
      _meta:close()
      _meta = nil
      _meta_db = nil
    end

    if _envs then
      for _,ed in ipairs(_envs) do
        ed[1]:close()
      end
      _envs = nil
    end
  end

  local function backup(backup_path_)
    if _meta then
      logi("backing up meta")
      _meta:copy(backup_path_)
    end
    for i,ed in ipairs(_envs) do
      logi("backing up env",i)
      ed[1]:copy(backup_path_)
    end
  end

  init()
  local self = {
    get = get,
    put = put,
    del = del,
    search = search,
    set_slot = internal_set_slot,
    get_slot = internal_get_slot,
    out = internal_out_slot,
    matching_keys = matching_keys,
    close = close,
    backup = backup,
    cache = function() end,
    sort_updated_names = function(names_)
      table.sort(names_)
      return names_
    end
  }

  self.sequence_storage = function(name_,numslots_)
    return {
      get_slot = function(idx_,offset_)
        return self.get_slot(name_,idx_,offset_)
      end,
      set_slot = function(idx_,offset_,a,b,c)
        return self.set_slot(name_,idx_,offset_,a,b,c)
      end,
      save = function() -- nop
      end,
      cache = function(name_) return self.cache(name_) end,
      reset = function()  end,
           }
  end

  return self
end
