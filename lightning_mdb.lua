module("lightning_mdb",package.seeall)
local lightningmdb_lib=require "lightningmdb"
require "helpers"

local lightningmdb = _VERSION=="Lua 5.2" and lightningmdb_lib or lightningmdb

function chained_db(dbs_,generate_new_db_)

  local function get(k)
    for _,d in ipairs(dbs_) do
      local v = d:get(k)
      if v then return v end
    end
    return nil
  end

  local function out(k)
    for _,d in ipairs(dbs_) do
      if d:out(k) then return true end
    end
    return nil
  end

  local self = {
    get = get,
    put = put,
    out = out,
    matching_keys = matching_keys,
    close = close,
  }

  self.sequence_storage = function(name_,numslots_)
    return sequence_storage(self,name_,numslots_)
  end

  return self
end

local NUM_PAGES = 25600

function lightning_mdb(base_dir_,read_only_,num_pages_)
  local _meta,_meta_db
  local _envs = {}

  local function txn(env_,func_)
    local t = env_:txn_begin(nil,0)
    local rv = func_(t)
    if not rv then
      t:abort()
      return nil
    end
    t:commit()
    return rv
  end

  local function new_env_factory(name_)
    local e = lightningmdb.env_create()
    local full_path = base_dir_.."/"..name_
    e:set_mapsize((num_pages_ or NUM_PAGES)*4096)
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
        local rv = t:put(_envs[#_envs][2],k,v)
        if rv then return rv end
        add_env()
        return put(k,v)
      end)
  end

  local function get(k)
    if string.find(k,"metadata=",1,true) then
      return txn(_meta,function(t) return t:get(_meta_db,k) end)
    end

    for _,ed in ipairs(_envs) do
      local rv = txn(ed[1],function(t) return t:get(ed[2],k) end)
      if rv then return rv end
    end

  end


  local function out(k)
    if string.find(k,"metadata=",1,true) then
      return txn(_meta,function(t) return t:del(_meta_db,k,nil) end)
    end

    for _,ed in ipairs(_envs) do
      txn(ed[1],function(t) return t:del(ed[2],k,nil) end)
    end
  end

  local function matching_keys(prefix_,level_,meta_)

    local function helper(db)
      return function(t)
        local cur = t:cursor_open(db)
        local k,v = prefix_,nil
        repeat
          k,v = cur:get(k,lightningmdb.MDB_NEXT)
          if k and bounded_by_level(k,prefix_,level_ or 1) then
            coroutine.yield(k,v)
          end
        until not k
        cur:close()
             end
    end

    if meta_ then
      return coroutine.wrap(function() txn(_meta,helper(_meta_db)) end)
    end

    return coroutine.wrap(
      function()
        for _,ed in ipairs(_envs) do
          txn(ed[1],helper(ed[2]))
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
