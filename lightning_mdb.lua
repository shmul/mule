module("lightning_mdb",package.seeall)
local lightningmdb_lib= require("lightningmdb")
local pp = require("purepack")
require "helpers"
require "conf"


local lightningmdb = _VERSION=="Lua 5.2" and lightningmdb_lib or lightningmdb

local NUM_PAGES = 256000
local MAX_SLOTS_IN_SPARSE_SEQ = 10
local SLOTS_PER_PAGE = 16
local MAX_CACHE_SIZE = 2000
local CACHE_FLUSH_SIZE = 50

function lightning_mdb(base_dir_,read_only_,num_pages_,slots_per_page_)
  local _metas = {}
  local _pages = {}
  local _slots_per_page
  local _cache = {}
  local _nodes_cache = {}


  function flush_cache_logger()
    local a = table_size(_cache)
    local b = table_size(_nodes_cache)
    if a>0 or b>0 then
      logi("lightning_mdb flush_cache",a,b)
    end
  end

  local _flush_cache_logger = every_nth_call(10,flush_cache_logger)

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

  local function new_env_factory(name_,create_)
    local full_path = base_dir_.."/"..name_
    if not directory_exists(full_path) then
      if not create_ then
        logw("directory doesn't exist",full_path)
        return nil
      end
      os.execute("mkdir -p "..full_path)
    end

    local e = lightningmdb.env_create()
    local r,err = e:set_mapsize((num_pages_ or NUM_PAGES)*4096)
    _,err = e:open(full_path,read_only_ and lightningmdb.MDB_RDONLY or 0,420)
    if err then
      loge("new_env_factory failed",err)
      return nil
    end

    logi("new_env_factory",full_path,t2s(e:stat()))
    return e
  end

  local function new_db(env_)
    return txn(env_,
               function(t)
                 local r,err = t:dbi_open(nil,read_only_ and 0 or lightningmdb.MDB_CREATE)
                 if err then
                   loge("new_db",err)
                   return nil
                 end
                 return r
               end)
  end

  local function add_env(array_,label_,create_)
    local e = new_env_factory(label_.."."..tostring(#array_),create_)
    if not e then return nil end
    logi("creating new env pair for",label_,#array_)
    table.insert(array_,{e,new_db(e)})
    return array_[#array_]
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

  local function native_put(k,v,meta_)
    local function put_in_ed(ed_)
      local rv,err = txn(ed_[1],function(t) return t:put(ed_[2],k,v,0) end)
      return rv,err
    end

    local function helper1(array_,label_)
      local rv,err
      for i,ed in ipairs(array_) do
        rv,err = put_in_ed(ed)
        if not err then return nil end
        -- when we put a key somewhere we must make sure no *previous* DB has the same key
        txn(ed[1],
            function(t)
              if t:get(ed[2],k) then
                logw("native_put removing key",label_,i,k)
                t:del(ed[2],k,nil)
              end
            end)
      end
      return err
    end

    local function helper0(array_,label_)
      local err = helper1(array_,label_)
      if err then
        logw("native_put",k,err)
        local ed = add_env(array_,label_,true)
        rv,err = put_in_ed(ed)  -- we attempt again, but only once.
        logi("native_put 2nd attempt",k,err)
      end
      return err
    end

    return (meta_ or string.find(k,"metadata=",1,true)) and helper0(_metas,"meta") or helper0(_pages,"page")
  end

  local function put(k,v,dont_cache_,meta_)
    if dont_cache_ then
      return native_put(k,v,meta_)
    end
    _cache[k] = v
    return _cache[k]
  end

  local function put_node(k,node)
    _nodes_cache[k] = node
    return _nodes_cache[k]
  end

  local function flush_cache(amount_,step_)
    _flush_cache_logger()

    if not amount_ then -- if we are flushing everything, we want to know how much we are going to flush
      flush_cache_logger()
    end

    local step_helper = every_nth_call(10,step_ or function() end)

    local size,st,en = random_table_region(_cache,amount_)
    if size>0 then
      for k,v in iterate_table(_cache,st,en) do
        native_put(k,v,false)
        _cache[k] = nil
        step_helper()
      end
    end

    size,st,en = random_table_region(_nodes_cache,amount_)
    if size>0 then
      for k,v in iterate_table(_nodes_cache,st,en) do
        native_put(k,pack_node(v),true)
        _nodes_cache[k] = nil
        step_helper()
      end
    end
    return size>0 -- this only addresses the nodes cache but it actually suffices as for every page there is a node
  end

  local function native_get(k,meta_)
    local function helper(array_)
      for _,ed in ipairs(array_) do
        local rv,err = txn(ed[1],function(t) return t:get(ed[2],k) end)
        if rv then return rv end
      end
    end

    if meta_ or string.find(k,"metadata=",1,true) then
      return helper(_metas)
    end
    return helper(_pages)
  end

  local function get(k,dont_cache_)
    if dont_cache_ then
      return native_get(k)
    end
    if not _cache[k] then
      _cache[k] = native_get(k)
    end
    return _cache[k]
  end

  local function get_node(k)
    if not _nodes_cache[k] then
      _nodes_cache[k] = unpack_node(k,native_get(k,true))
    end
    return _nodes_cache[k]
  end


  local function init()
    local function populate_env(array_,label_)
      add_env(array_,label_,true)
      while add_env(array_,label_,false) do
        -- nop
      end
    end
    populate_env(_metas,"meta")
    populate_env(_pages,"page")
    _slots_per_page = get("metadata=slots_per_page")
    if not _slots_per_page then
      _slots_per_page = slots_per_page_ or SLOTS_PER_PAGE
      put("metadata=slots_per_page",_slots_per_page,true)
    end
  end


  local function del(k,meta_)
    local function helper(array_)
      for _,ed in ipairs(array_) do
        local rv,err = txn(ed[1],function(t) return t:del(ed[2],k,nil) end)
      end
    end

    _cache[k] = nil
    _nodes_cache[k] = nil
    if meta_ or string.find(k,"metadata=",1,true) then
      helper(_metas)
    end
    helper(_pages)
  end

  local function search(prefix_)
    --flush_cache()
    for _,ed in ipairs(_metas) do
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
    del(name_,true)
  end

  local function has_sub_keys(prefix_)
    local function helper(env,db)
      local t,err = env:txn_begin(nil,0) -- this may be called with an opened write cursor so we don't restrict ourselves to readonly
      local find = string.find
      local byte = string.byte
      local found = false
      local cur = t:cursor_open(db)
      local k = cur:get_key(prefix_,#prefix_==0 and lightningmdb.MDB_FIRST or lightningmdb.MDB_SET_RANGE)
      repeat
        local prefixed = k and find(k,prefix_,1,true)
        if not find(k,"metadata=",1,true) and prefixed and k~=prefix_ then
          found = true
        end
        if not prefixed then
          k = nil
        else
          k = cur:get_key(k,lightningmdb.MDB_NEXT)
        end
      until not k or found
      cur:close()
      t:commit()
      return found
    end

    for _,ed in ipairs(_metas) do
      if helper(ed[1],ed[2]) then return true end
    end
  end

  local function matching_keys(prefix_,level_)
    local function helper(env,db)
      local t,err = env:txn_begin(nil,lightningmdb.MDB_RDONLY)
      local find = string.find
      local byte = string.byte

      local cur = t:cursor_open(db)
      local k = cur:get_key(prefix_,#prefix_==0 and lightningmdb.MDB_FIRST or lightningmdb.MDB_SET_RANGE)
      repeat
        local prefixed = k and find(k,prefix_,1,true)
        if not find(k,"metadata=",1,true) and prefixed and bounded_by_level(k,prefix_,level_) then
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
                            flush_cache(UPDATE_AMOUNT/32) -- we keep it here mainly for the sake of the unit tests
                            for _,ed in ipairs(_metas) do
                              helper(ed[1],ed[2])
                            end
                          end)
  end



  local function close()
    local function helper(array_)
      if not array_ then return end
      for _,ed in ipairs(array_) do
        ed[1]:close()
      end
    end

    logi("lightning_mdb close")
    flush_cache()
    helper(_metas)
    _metas = nil
    helper(_pages)
    _pages = nil
  end

  local function backup(backup_path_)
    local function helper(array_,label_)
      if not array_ then return end
      for _,ed in ipairs(array_) do
        logi("backing up",label_,i)
        ed[1]:copy(backup_path_)
      end
    end

    if _meta then
      helper(_metas,"meta")
    end
    if _pages then
      helper(_pages,"page")
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
    has_sub_keys = has_sub_keys,
    matching_keys = matching_keys,
    close = close,
    backup = backup,
    flush_cache = flush_cache,
    cache = function() end,
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
