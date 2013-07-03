module("trie",package.seeall)
require "helpers"
local _,p = pcall(require,"purepack")

local new,unpack
local methods = nil

local function split(string_)
  local a,b = string.match(string_,"([^%.;]+)[%.;](.+)")
  if not a then
    a = string_
  end
  return a,b
end

local function insert(self,string_)
  if not string_ then
    self._eos = true
    return self
  end

  local a,b =  split(string_)
  if not a then
    return nil
  end

  self._size = (self._size or 0) + 1
  self._children = self._children or {}
  if not self._children[a] then
    self._children[a] = new()
  end
  return self._children[a]:insert(b)
end

local function find(self,string_,partial_,prefix_)
  if not string_ then
    return (self._eos or partial_) and self
  end
  if not self._children then
    return nil
  end
  local a,b = split(string_)
  if self._children[a] then
    return self._children[a]:find(b,partial_)
  end
  if prefix_ then
    for k,v in pairs(self._children) do
      if is_prefix(k,string_) then
        return v:find(b,partial_)
      end
    end
  end
end

local function delete(self,string_,prefix_)
  -- we don't really reclaim space but simply tag the string(s) as not present
  for k,n in self:traverse(string_,prefix_) do
    n._eos = false
    self._size = self._size - 1
  end
end

local function traverse(self,path_,prefix_,sorted_)
  local format = string.format

  function helper(n,p_)
    if n._eos then
      coroutine.yield(p_,n)
    end
    if not sorted_ then
      for k,v in pairs(n._children or {}) do
        local path = (p_ and #p_>0 and format("%s.%s",p_,k)) or k
        helper(v,path)
      end
    else
      for _,k in ipairs(table.sort(keys(n._children or {}))) do
        local path = (p_ and #p_>0 and format("%s.%s",p_,k)) or k
        helper(n._children[k],path)
      end
    end
  end

  return coroutine.wrap(
    function()
      local root = self
      if path_ and #path_>0 then root = self:find(path_,true,prefix_) end

      if root then helper(root,path_) end
    end)
end

local function size(self)
  return self._size or 0
end


local function tostring(self)
  local s = {}
  for k,_ in self:traverse() do
    table.insert(s,k)
  end
  return table.concat(s,"\n")
end

local function pack(self)
  return p.pack(self)
end



unpack = function(packed_)
  local self = p.unpack(packed_)
  function helper(n)
    for _,v in pairs(n._children or {}) do
      copy_table(methods(),v)
      helper(v)
    end
  end
  copy_table(methods(),self)
  helper(self)
  return self
end

methods = function()
  return {
    insert = insert,
    delete = delete,
    find = find,
    traverse = traverse,
    size = size,
    pack = pack,
         }
end

new = function()
  return methods()
end



return {
  new = new,
  unpack = unpack
       }