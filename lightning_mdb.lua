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
local MAX_DBS = 10000

function lightning_mdb(base_dir_,read_only_,num_pages_)
  local meta_file = base_dir_.."/db.meta"
  local _meta = nil
  local _dbs = {}
  local _e = nil

  local function transaction(func_)
    local t = _e:txn_begin(nil,0)
    local rv = func_(t)
    if not rv then
      t:reset()
      return nil
      end
    t:commit()
    return rv
  end

  local function new_db(name_)
    return transaction(
      function(t)
        return t:dbi_open(name_,read_only_ and 0 or lightningmdb.MDB_CREATE)
      end)
  end

  local function init()
    _e = lightningmdb.env_create()
    _e:set_mapsize((num_pages_ or NUM_PAGES)*4096)
    _e:set_maxdbs(MAX_DBS)

    _e:open(base_dir_,read_only_ and lightningmdb.MDB_RDONLY or 0,420)
    _meta = new_db("db.meta")
    print(_meta)
  end


  local function put(k,v)
    return transaction(
      function(t)
        if string.find(k,"metadata=",1,true) then
          return t:put(_meta,k,v,0)
        end

        local rv = t:put(_dbs[#_dbs],k,v)
        if rv then return rv end
        _dbs[#_dbs+1] = new_db(tostring(#_dbs+1))
        return t:put(_dbs[#_dbs],k,v)
      end)
  end

  local function get(k)
    return transaction(
      function(t)
        if string.find(k,"metadata=",1,true) then
          return t:get(_meta,k)
        end
        for _,d in ipairs(_dbs) do
          local rv = t:get(d,k)
          if rv then return rv end
        end
      end)
  end


  local function out(k)
    return transaction(
      function(t)
        return each_db(function(d)
                         if not t:get(d,k) then return false end
                         t:out(d,k)
                         return true
                       end)
      end)
  end


  local function matching_keys(prefix_,level_)
    return coroutine.wrap(
      function()
        return transaction(
          function(t)
            return each_db(function(d)
                             local cur = t:cursor_open(d)
                             local k,v = prefix_,nil
                             repeat
                               k,v = cursor:get(k,lightningmdb.MDB_NEXT)
                               if k and bounded_by_level(k,prefix_,level_) then
                                 coroutine.yield(k,v)
                               end
                             until not k
                             cur:close()
                           end)
          end)
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
