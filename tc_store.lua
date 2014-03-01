require "sequence_store"
local ks,kyoto = pcall(require,"kyotocabinet")
local ts,tokyo = pcall(require,"tokyocabinet") -- tokyocabinet require returns true/false
cabinet = (ts and tokyocabinet) or (ks and kyoto)

if not cabinet then
  return
end

cabinet.suffix = (ks and cabinet==kyoto and ".kct") or (ts and cabinet==tokyocabinet and ".bdb") or "none"
cabinet.using = (ks and "kyotocabinet") or (ts and "tokyocabinet") or "none"

local using_msg = (cabinet==kyoto and "kyotocabinet") or (cabinet==tokyocabinet and "tokyocabinet")
logi("using ",cabinet.using)


function generate_functions()
  local db

  local function full_name(database_)
    if string.find(database_,cabinet.suffix,1,true)==#database_-#cabinet.suffix+1 then
      return database_
    end
    return database_..cabinet.suffix
  end

  if cabinet~=kyoto then
    return
      function(database_,readonly_)
      -- we use this either to open a file, or to set the db value to an externally
      -- opened db
      if type(database_)=="string" then
        db = cabinet.bdbnew()
        local perm = (readonly_ and db.OREADER) or (db.OWRITER+db.OCREAT)
        if not db:open(full_name(database_),perm) then
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
      function(k) return db:out(k) end
  end

  return
    function(database_,readonly_)
    -- we use this either to open a file, or to set the db value to an externally
    -- opened db
    if type(database_)=="string" then
      db = cabinet.DB:new()
      local perm = (readonly_ and cabinet.DB.OREADER) or (cabinet.DB.OWRITER+cabinet.DB.OCREATE)
      if not db:open(full_name(database_),perm) then
        local error = db:error()
        logf("unable to open db",database_,error:code(),error:name(),error:message())
        return nil,error:name()
      end
    else
      db = database_
    end
    return db
    end,
    function() db:close() end,
    function(k) return db:get(k) end,
    function(k,v) return db:set(k,v) end,
    function(k) return db:match_prefix(k) end,
    function(k) return db:remove(k) end
end


function cabinet_db(db_name_,readonly_)
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_out = generate_functions()

  tc_init(db_name_,readonly_)
  local function matching_keys(prefix_,level_)
    return coroutine.wrap(
      function()
        local find = string.find
        local keys = tc_fwmkeys(prefix_)
        for _,k in ipairs(keys or {}) do
          if bounded_by_level(k,prefix_,level_) and not find(k,"metadata=",1,true) then
            coroutine.yield(k)
          end
        end
      end)
  end

  local self = {
    get = tc_get,
    put = tc_put,
    out = tc_out,
    matching_keys = matching_keys,
    close = tc_done,
    cache = function() end,
    sort_updated_names = function(names_)
      table.sort(names_)
      return names_
    end

  }
  self.sequence_storage = function(name_,numslots_)
    return sequence_storage(self,name_,numslots_)
  end

  return self
end
