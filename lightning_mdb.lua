--module("lightning_mdb",package.seeall)
local lightningmdb_lib= require("lightningmdb")
local pp = require("purepack")
require "helpers"
require "conf"

local disable_cache = false

local lightningmdb = _VERSION >= "Lua 5.2" and lightningmdb_lib or lightningmdb

local NUM_PAGES = 256000
local MAX_SLOTS_IN_SPARSE_SEQ = 10
local SLOTS_PER_PAGE = 16
local MAX_CACHE_SIZE = 2000
local CACHE_FLUSH_SIZE = 50

local function lightning_mdb(base_dir_,read_only_,num_pages_,slots_per_page_)
  local _metas = {}
  local _pages = {}
  local _slots_per_page
  local _cache = {}
  local _nodes_cache = {}
  local _readonly_txn = {}
  local _increment = nil

  local function flush_cache_logger()
    local a = table_size(_cache)
    local b = table_size(_nodes_cache)
    if a>0 or b>0 then
      logi("lightning_mdb flush_cache",a,b)
    end
  end

  local _flush_cache_logger = every_nth_call(10,flush_cache_logger)

  local function acquire_readonly_txn(env_)
    if not _readonly_txn[env_] then
      local t,err,errno = env_:txn_begin(nil,lightningmdb.MDB_RDONLY)
      if not t then
        logw("acquire_readonly_txn",err)
        return nil,err
      end
      _readonly_txn[env_] = {t,0}
    end
    _readonly_txn[env_][2] = _readonly_txn[env_][2] + 1
    return _readonly_txn[env_][1]
  end

  local function release_readonly_txn(env_)
    if not _readonly_txn[env_] then return nil end

    _readonly_txn[env_][2] = _readonly_txn[env_][2] -1
    if _readonly_txn[env_][2]==0 then
      _readonly_txn[env_][1]:abort() -- readonly transactions can be aborted, there is no commit
      _readonly_txn[env_] = nil
    end
  end

  local function txn(env_,func_,read_only_)
    local rv,t,err,errno
    if read_only_ then
      t = acquire_readonly_txn(env_)
    else
      t,err,errno = env_:txn_begin(nil,0)
    end

    if err then
      if not t then
        logw("txn - failed to create transaction",err)
        loge(err,debug.traceback())
        return nil,err
      end
      read_only_ = false
    end
    rv,err,errno = func_(t)
    err = err or (errno and tostring(errno))
    if err then
      if read_only_ then
        release_readonly_txn(env_)
      else
        pcall_wrapper(function() t:abort() end)
      end
      return nil,err
    end
    if read_only_ then
      release_readonly_txn(env_)
      return rv,err
    end
    local c_rv,c_err = t:commit()
    if c_rv then
      return rv,err
    end
    return c_rv,c_err
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
    local _,err = e:set_mapsize((num_pages_ or NUM_PAGES)*4096)
    local flags = lightningmdb.MDB_NOTLS+(read_only_ and lightningmdb.MDB_RDONLY or (lightningmdb.MDB_MAPASYNC + lightningmdb.MDB_WRITEMAP))
    _,err = e:open(full_path,flags,420) -- 420 is the open mode
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

  local function native_get(k,meta_)
    local function helper(array_)
      for i,ed in ipairs(array_) do
        local rv,err = txn(ed[1],function(t) return t:get(ed[2],k) end,true)
        if rv then return rv,i end
      end
    end

    if meta_ or special_key(k) then
      return helper(_metas)
    end
    return helper(_pages)
  end

  local function native_put(k,v,meta_,idx_hint_)
    local function put_in_ed(ed_)
      local rv,err = txn(ed_[1],
                         function(t)
                           local rv,err = t:put(ed_[2],k,v,0)
                           if err then
                             return nil,err
                           end
                         end)

      return rv,err
    end

    local function del_with_index(array_,index_)
      local ed = array_[index_]
      txn(ed[1],
          function(t)
            if t:get(ed[2],k) then
              --logw("native_put del_with_index",index_,k)
              t:del(ed[2],k,nil)
            end
          end)
    end

    local function helper1(array_,label_)
      local last_err
      local first_db = idx_hint_ or 1
      for i=first_db,#array_ do
        local ed = array_[i]
        local rv,err = put_in_ed(ed)
        if not err then
          return nil
        end

        last_err = err
      end
      return last_err
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

    if meta_ or special_key(k) then
      return helper0(_metas,"meta")
    end
    return helper0(_pages,"page")
  end

  local function put(k,v)
    if special_key(k) or disable_cache then
      local _,idx = native_get(k)
      return native_put(k,v,special_key(k),idx)
    end

    local idx = _cache[k] and _cache[k][2] or nil
    _cache[k] = {v,idx,true}
    return _cache[k][1]
  end

  local function put_node(k,node)
    if disable_cache then
      return native_put(k,pack_node(node),true)
    end

    if not _nodes_cache[k] then
      -- a new key? We write it to the DB, so it will be picked up when looking for keys
      -- (find_keys, matching_keys, has_sub_keys)
      native_put(k,pack_node(node),true)
    end

    local idx = _nodes_cache[k] and _nodes_cache[k][2] or nil
    _nodes_cache[k] = {node,idx,true}
    return _nodes_cache[k][1]
  end

  local function sync()
    local function helper(array_)
      if not array_ then return end
      for _,ed in ipairs(array_) do
        local rv,err = ed[1]:sync(1)
        if err then
          logw("sync",err)
        end
      end
    end
    helper(_metas)
    helper(_pages)
  end

  local function flush_cache(amount_,step_)
    _flush_cache_logger()

    if not amount_ then -- if we are flushing everything, we want to know how much we are going to flush
      flush_cache_logger()
    end

    local log_progress = not amount_ and every_nth_call(PROGRESS_AMOUNT/10,function(count_) logi("flush_cache - progress",count_*10) end)
    local insert = table.insert

    local function helper(cache_,meta_)
      local size,st,en = random_table_region(cache_,amount_)
      if size==0 then return 0 end

      local keys_array = {}

      for k,v in iterate_table(cache_,st,en) do
        insert(keys_array,{k,v})
      end
      for i=1,#keys_array,10 do
        for j=i,math.min(#keys_array,i+9) do
          local k,vidx = keys_array[j][1],keys_array[j][2]
          local v,idx,dirty = vidx[1],vidx[2],vidx[3]
          local payload = v
          if dirty then
            if meta_ then
              payload = pack_node(v)
              if not payload then
                loge("flush_cache unable to pack",k)
              end
            end
            if payload then
              native_put(k,payload,meta_,idx)
            end
          end
          cache_[k] = nil
        end
        if step_ then step_() end
        if log_progress then log_progress() end
      end
      return size
    end

    helper(_cache,false)
    local size = helper(_nodes_cache,true)
    sync()
    return size>0 -- this only addresses the nodes cache but it actually suffices as for every page there is a node
  end


  local function get(k,dont_cache_)
    if dont_cache_ or disable_cache or not _cache[k] then
      local v,idx = native_get(k)

      if dont_cache_ or disable_cache then
        return v
      end
      _increment("mule.lightning_mdb.get.cache_miss")
      _cache[k] = {v,idx}
    end
    return _cache[k][1]
  end

  local function get_node(k)
    if disable_cache or not _nodes_cache[k] then
      local v,idx = native_get(k,true)
      v = v and unpack_node(k,v)
      if not v or disable_cache then return v end
      _increment("mule.lightning_mdb.get_node.cache_miss")
      _nodes_cache[k] = {v,idx}
    end
    return _nodes_cache[k][1]
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
    _slots_per_page = native_get("metadata=slots_per_page",true)
    if not _slots_per_page then
      _slots_per_page = slots_per_page_ or SLOTS_PER_PAGE
      native_put("metadata=slots_per_page",_slots_per_page,true)
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
    if meta_ or special_key(k) then
      return helper(_metas)
    end
    helper(_pages)
  end

  local function search(prefix_)
    for _,ed in ipairs(_metas) do
      local t = acquire_readonly_txn(ed[1])
      local cur = t:cursor_open(ed[2])
      local k,v = cur:get(prefix_,lightningmdb.MDB_SET_RANGE)
      cur:close()
      release_readonly_txn(ed[1])
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

    if node._seq then
      -- trying to access one past the size is interpreted as getting the latest index
      if node._size==idx_ then
        return node._seq.latest_timestamp()
      end

      local slot = node._seq.find_by_index(idx_)
      if not slot then
        return no_data()
      end
      if not offset_ then
        return slot._timestamp,slot._hits,slot._sum
      end
      return (offset_==0 and slot._timestamp) or (offset_==1 and slot._hits) or (offset_==2 and slot._sum)
    end

    -- trying to access one past the size is interpreted as getting the latest index
    if node._size==idx_ then
      return node._latest
    end

    local key,p,q = page_key(name_,idx_)
    local page_data = get(key,false)

    if not page_data then
      return no_data()
    end

    return get_slot(page_data,q,offset_)
  end

  local function internal_set_slot(name_,idx_,offset_,timestamp_,hits_,sum_)
    local function new_page_data()
      _increment("mule.lightning_mdb.internal_set_slot.new_page_data")
      return string.rep(string.char(0),pp.PNS*3*_slots_per_page)
    end

    -- the name is used as a key for the metadata
    local node = get_node(name_)

    if not node then
      -- a new node keeps a sparse_sequence instead of allocating actual pages for the slots
      local _,step,period = split_name(name_)
      node = { _latest = 0, _seq = sparse_sequence(name_), _size = period/step }
    end

    -- trying to access one past the sequence size is interpreted as
    -- getting the latest index
    if node._size==idx_ then
      node._latest = timestamp_ -- this is actually the index of the latest slot
      put_node(name_,node)
      return
    end
    if node._seq then
      node._seq.set(timestamp_,hits_,sum_)
      if #node._seq.slots()==MAX_SLOTS_IN_SPARSE_SEQ then
      _increment("mule.lightning_mdb.internal_set_slot.create_pages")
        -- time to create actual pages
        local slots = node._seq.slots()
        node._latest = node._seq.latest_timestamp()
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

  local function find_keys(prefix_,substring_)
    local function helper(env,db)
      local t,err = acquire_readonly_txn(env)

      if err then
        logw("find_keys",err)
        return
      end

      local find = string.find
      local found = false
      local cur = t:cursor_open(db)
      local k = cur:get_key(prefix_,#prefix_==0 and lightningmdb.MDB_FIRST or lightningmdb.MDB_SET_RANGE)
      repeat
        local prefixed = k and find(k,prefix_,1,true)
        if prefixed and k~=prefix_ then
          if find(k,substring_,1,true) then
            coroutine.yield(k)
          end
        end
        if not prefixed then
          k = nil
        else
          k = cur:get_key(k,lightningmdb.MDB_NEXT)
        end
      until not k
      cur:close()
      release_readonly_txn(env)
      return found
    end

    return coroutine.wrap(
      function()
        for _,ed in ipairs(_metas) do
          if helper(ed[1],ed[2]) then return true end
        end
    end)
  end

  local function has_sub_keys(prefix_)
    local function helper(env,db)
      local t,err = acquire_readonly_txn(env)

      if err then
        logw("has_sub_keys",err)
        return
      end

      local find = string.find
      local found = false
      local cur = t:cursor_open(db)
      local k = cur:get_key(prefix_,#prefix_==0 and lightningmdb.MDB_FIRST or lightningmdb.MDB_SET_RANGE)
      repeat
        local prefixed = k and find(k,prefix_,1,true)
        if prefixed and k~=prefix_ then
          found = true
        end
        if not prefixed then
          k = nil
        else
          k = cur:get_key(k,lightningmdb.MDB_NEXT)
        end
      until not k or found
      cur:close()
      release_readonly_txn(env)
      return found
    end

    for _,ed in ipairs(_metas) do
      if helper(ed[1],ed[2]) then return true end
    end
  end

  local function matching_keys(prefix_,level_)
    local reported = {}
    local function helper(env,db)
      local t,err = acquire_readonly_txn(env)
      if not t or err then
        logw("matching_keys",err)
        return
      end
      local find = string.find
      local cur = t:cursor_open(db)
      local k = cur:get_key(prefix_,#prefix_==0 and lightningmdb.MDB_FIRST or lightningmdb.MDB_SET_RANGE)

      repeat
        local prefixed = k and find(k,prefix_,1,true)
        if prefixed then
          if bounded_by_level(k,prefix_,level_) then
            if not reported[k] then
              -- since keys may appear in multiple DBs (probably due to a bug), we want to report them only once
              coroutine.yield(k)
              reported[k] = true
            end
            k = cur:get_key(k,lightningmdb.MDB_NEXT)
          else
            local trimmed = trim_to_level(k,prefix_,level_)
            if trimmed then
              local next_key = trimmed..";"
              local nk = cur:get_key(next_key,lightningmdb.MDB_SET_RANGE)
              k = nk
            else
              k = nil
            end
          end
        else
          k = nil
        end
      until not k
      cur:close()
      release_readonly_txn(env)
    end
    _increment("mule.lightning_mdb.matching_keys")
    return coroutine.wrap(
      function()
        for _,ed in ipairs(_metas) do
          helper(ed[1],ed[2])
        end
    end)
  end

  local function dump_kv(prefix_,with_values_)
    local str = stdout("")

    local function helper(env,db)
      local t,err = acquire_readonly_txn(env)
      if not t or err then
        logw("matching_keys",err)
        return
      end
      local find = string.find
      local cur = t:cursor_open(db)
      local k = cur:get_key(prefix_,#prefix_==0 and lightningmdb.MDB_FIRST or lightningmdb.MDB_SET_RANGE)
      repeat
        local prefixed = k and find(k,prefix_,1,true)
        if prefixed then
          if with_values_ then
            local _,v = cur:get(k,lightningmdb.MDB_GET_CURRENT)
            str.write("  ",k," ",t2s(unpack_node(k,v)),"\n")
          else
            str.write("  ",k,"\n")
          end
          k = cur:get_key(k,lightningmdb.MDB_NEXT)
        else
          k = nil
        end
      until not k
      cur:close()
      release_readonly_txn(env)
    end

    for i,ed in ipairs(_metas) do
      str.write("== meta",i," ",ed[1]," ",ed[2],"\n")
      helper(ed[1],ed[2])
    end
    for i,ed in ipairs(_pages) do
      str.write("== page",i," ",ed[1]," ",ed[2],"\n")
      helper(ed[1],ed[2])
    end
  end

  local function dump_keys(prefix_)
    return dump_kv(prefix_ or "")
  end

  local function dump_values(prefix_)
    return dump_kv(prefix_ or "",true)
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
    native_put = function(k,v,meta_) return native_put(k,v,meta_) end, -- we specifically disable passing the hint index
    del = del,
    search = search,
    set_slot = internal_set_slot,
    get_slot = internal_get_slot,
    out = internal_out_slot,
    find_keys = find_keys,
    has_sub_keys = has_sub_keys,
    matching_keys = matching_keys,
    close = close,
    backup = backup,
    flush_cache = flush_cache,
    cache = function() end,
    dump_keys = dump_keys,
    dump_values = dump_values,
    set_increment = function(increment_) _increment = increment_ end,
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

return {
  lightning_mdb = lightning_mdb
}
