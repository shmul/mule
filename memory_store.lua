require "sequence_store"

function in_memory_db()
  local _storage = {}

  local function find_keys(prefix_,substring_)
    local find = string.find
    return coroutine.wrap(
      function()
        for k,_ in pairs(_storage) do
          if is_prefix(k,prefix_) and find(k,substring_,1,true) then
            coroutine.yield(k)
          end
        end
    end)
  end

  local function has_sub_keys(prefix_)
    local find = string.find
    for k,_ in pairs(_storage) do
      if is_prefix(k,prefix_) and prefix_~=k then
        return true
      end
    end
  end

  local function matching_keys(prefix_,level_)
    local find = string.find
    return coroutine.wrap(
      function()
        for k,_ in pairs(_storage) do
          if is_prefix(k,prefix_) and bounded_by_level(k,prefix_,level_)  then
            coroutine.yield(k)
          end
        end
      end)
  end

  local self = {
    get = function(key_) return _storage[key_] end,
    put = function(key_,value_) _storage[key_] = value_ end,
    out = function(key_) _storage[key_] = nil end,
    has_sub_keys = has_sub_keys,
    find_keys = find_keys,
    matching_keys = matching_keys,
    close = function () end,
    cache = function() end,
    flush_cache = function() end,
  }

  self.sequence_storage = function(name_,numslots_)
    return sequence_storage(self,name_,numslots_)
  end

  return self
end
