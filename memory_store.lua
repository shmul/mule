function in_memory_db()
  local _storage = {}

  local function matching_keys(prefix_)
    return coroutine.wrap(
      function()
        for k,_ in pairs(_storage) do
          if is_prefix(k,prefix_) then
            coroutine.yield(k)
          end
        end
      end)
  end


  return {
    get = function(key_) return _storage[key_] end,
    put = function(key_,value_) _storage[key_] = value_ end,
    out = function(key_) _storage[key_] = nil end,
    matching_keys = matching_keys,
    close = function () end
         }
end
