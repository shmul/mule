local lightningmdb_lib=require "lightningmdb"

local lightningmdb = _VERSION=="Lua 5.2" and lightningmdb_lib or lightningmdb

function chained_db(dbs_,generate_new_db_)


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

  local _e = lightningmdb.env_create()
  _e:set_mapsize((num_pages_ or NUM_PAGES)*4096)
  _e:set_maxdbs(MAX_DBS)

  _e:open(base_dir_,read_only_ and lightningmdb.MDB_RDONLY or 0)

  local function transaction(func_)
    local t = _e:txn_begin(nil,0)
    local rv = func_(t)
    if not rv then
      t:revert()
      return nil
      end
    t:commit()
    return rv
  end

  local function new_db(name_)
    return transaction(function(t)
                  return t:dbi_open(name_)
                end)
  end


  local function put(k,v)
    return transaction(
      function(t)
        if string.find(k,"metadata=",1,true) then
          return _t:put(_meta,k,v)
        end

        local rv = _t:put(dbs_[#dbs_],k,v)
        if rv then return rv end
        dbs_[#dbs_+1] = new_db(tostring(#dbs_+1))
        return _t:put(dbs_[#dbs_],k,v)
      end)
  end

  local function get(k)
    return transaction(function(t)
                         if string.find(k,"metadata=",1,true) then
                           return _t:get(_meta,k)
                         end
                         for _,d in ipairs(dbs_) do
                           local rv = _t:get(d,k)
                           if rv then return rv end
                         end
                       end)
  end


  local function each_db(func_)
    for _,d in ipairs(dbs_) do
      func_(d)
    end
  end

  local function out(k)
    return transaction(function(t)
                         return each_db(function(d)
                                          if not t:get(d,k) then return false end
                                          t:out(d,k)
                                          return true
                                        end)
                       end)
  end


  local function matching_keys(prefix_,level_)
    return coroutine.wrap(
      return transaction(function(t)
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
                         end))
  end

  local function close()
    _e:close()
    _e = nil
  end

  local self = {
    get = get,
    put = put,
    out = out,
    matching_keys = matching_keys,
    close = close,
    backup = backup
    cache = function() end,
    sort_updated_names = function(names_)
      table.sort(names_)
      return names_
    end
  }


end