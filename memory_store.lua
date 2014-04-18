require "sequence_store"

function in_memory_db()
  local _storage = {}

  local function matching_keys(prefix_,level_)
    local find = string.find
    return coroutine.wrap(
      function()
        for k,_ in pairs(_storage) do
          if is_prefix(k,prefix_) and bounded_by_level(k,prefix_,level_) and not find(k,"metadata=",1,true) then
            coroutine.yield(k)
          end
        end
      end)
  end

  local self = {
    get = function(key_) return _storage[key_] end,
    put = function(key_,value_) _storage[key_] = value_ end,
    out = function(key_) _storage[key_] = nil end,
    matching_keys = matching_keys,
    close = function () end,
    cache = function() end,
    update = function() end,
  }

  self.sequence_storage = function(name_,numslots_)
    return sequence_storage(self,name_,numslots_)
  end

  return self
end
