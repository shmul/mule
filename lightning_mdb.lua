module("lightning_mdb",package.seeall)
local lightningmdb_lib=require "lightningmdb"
require "helpers"

local lightningmdb = _VERSION=="Lua 5.2" and lightningmdb_lib or lightningmdb

local NUM_PAGES = 25600
local MAX_SLOTS_IN_SPARSE_SEQ = 10
local SLOTS_PER_PAGE = 16

function lightning_mdb(base_dir_,read_only_,num_pages_)
  local _meta,_meta_db
  local _envs = {}

  local function txn(env_,func_)
    local t = env_:txn_begin(nil,0)
    local rv,err = func_(t)
    if err then
      loge("txn failed",err)
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

  local function init()
    _meta = new_env_factory("meta")
    _meta_db = new_db(_meta)
    add_env()
  end


  local function put(k,v)
    if string.find(k,"metadata=",1,true) then
      return txn(_meta,function(t) return t:put(_meta_db,k,v,0) end)
    end
    return txn(_envs[#_envs][1],
               function(t)
                 local rv,err = t:put(_envs[#_envs][2],k,v,0)
                 if not err then return true end
                 add_env()
                 return put(k,v)
               end)
  end

  local function get(k)
    if string.find(k,"metadata=",1,true) then
      return txn(_meta,function(t) return t:get(_meta_db,k) end)
    end

    for _,ed in ipairs(_envs) do
      local rv,err = txn(ed[1],function(t) return t:get(ed[2],k) end)
      if not err then return rv end
    end
  end


  local function out(k)
    if string.find(k,"metadata=",1,true) then
      return txn(_meta,function(t) return t:del(_meta_db,k,nil) end)
    end

    for _,ed in ipairs(_envs) do
      local rv,err = txn(ed[1],function(t) return t:del(ed[2],k,nil) end)
    end
  end

  local function search(prefix_)
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
    local p = math.floor(idx_/SLOTS_PER_PAGE)
    local q = idx_%SLOTS_PER_PAGE
    return string.format("%04d|%s",p,name_),p,q
  end

  local function internal_get_slot(name_,idx_,offset_)
    -- the name is used as a key for the metadata
    local node = p.unpack(get(name_))
    if not node then return nil end

    -- trying to access one past the cdb size is interpreted as
    -- getting the latest index
    if node._size==idx_ then
      return node._latest
    end

    if node._seq then
      local slot = node._seq.find_by_index(idx_)
      if slot then
        if not offset then
          return slot._timestamp,slot._hits,slot._sum
        end
        return (offset==0 and slot._timestamp) or (offset==1 and slot._hits) or (offset==2 and slot._sum)
      end
    end

    local key,p,q = page_key(name_,idx_)
    local page_data = p.unpack(get(key))
    return get_slot(page_data,q,offset_)
  end

  local function internal_set_slot(name_,idx_,offset_,timestamp_,hits_,sum_)

    -- the name is used as a key for the metadata
    local node = p.unpack(get(name_))

    if not node then
      -- a new node keeps a sparse_sequence instead of allocating actual pages for the slots
      local metric,step,period = split_name(name_)
      node = { _latest = 0, _seq = sparse_sequence(name_), _size = period/step }
    end

    node._latest = math.max(node._latest,timestamp_)

    if node._seq then
      node._seq.update(timestamp_,sum_,hits_)
      if #node._seq.slots()==MAX_SLOTS_IN_SPARSE_SEQ then
        -- time to create actual pages
        local slots = node._seq.slots()

        local _,step,period = string.match(name_,"^(.+);(%w+):(%w+)$")
        for _,s in ipairs(node._seq.slots()) do
          local i,_ = calculate_idx(s._timestamp,step,period)
          local key,p,q = page_key(name_,i)
          local page_data = p.unpack(get(key)) or string.rep("%z",p.PNS*3*SLOTS_PER_PAGE)
          page_data = table.concat(set_slot(page_data,q,s._timestamp,s._hits,s._sum))
          put(key,p.pack(page_data))
        end
        node._seq = nil
      end
      put(name_,p.pack(node))
      return
    end

    local key,p,q = page_key(name_,idx_)
    local page_data = p.unpack(get(key))

    put(name_,p.pack(node))
    if not page_data then
      loge("unable to find page_data",key,timestamp_)
      return
    end
    page_data = table.concat(set_slot(page_data,q,timestamp_,hits_,sum_))
    put(key,p.pack(page_data))
  end


  local function matching_keys(prefix_,level_,meta_)

    -- we can't use coroutines due to the dreaded "attempt to yield across metamethod/C-call boundary" error
    local function helper(env,db)
      local t = env:txn_begin(nil,lightningmdb.MDB_RDONLY)
      local cur = t:cursor_open(db)
      local find = string.find
      local k,v = cur:get(prefix_,lightningmdb.MDB_SET_RANGE)
      repeat
        if k and find(k,prefix_,1,true) and bounded_by_level(k,prefix_,level_ or 1) then
          coroutine.yield(k,v)
        end
        k,v = cur:get(k,lightningmdb.MDB_NEXT)
      until not k
      cur:close()
      t:commit()
    end

    return coroutine.wrap(function()
                            if meta_ then
                              helper(_meta,_meta_db)
                              return
                            end
                            for _,ed in ipairs(_envs) do
                              helper(ed[1],ed[2])
                            end
                          end)
  end



  local function close()
    _e:close()
    _e = nil
  end

  local function backup(backup_path_)
    return _e:copy(backup_path_)
  end

  init()
  local self = {
    get = get,
    put = put,
    out = out,
    search = search,
    set_slot = internal_set_slot,
    get_slot = internal_get_slot,
    matching_keys = matching_keys,
    close = close,
    backup = backup,
    cache = function() end,
    sort_updated_names = function(names_)
      table.sort(names_)
      return names_
    end
  }

  return self
end
