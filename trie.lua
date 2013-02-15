module("trie",package.seeall)
require "helpers"


local new = nil

local function split(string_)
  local a,b = string.match(string_,"(%w+)%.(.+)")
  if not a then
    a = string_
  end
  return a,b
end

local function insert(self,string_)
  if not string_ then
    self._eos = true
    return
  end

  local a,b =  split(string_)
  if not a then
    return nil
  end

  self._children = self._children or {}
  if not self._children[a] then
    self._children[a] = new()
  end
  return self._children[a]:insert(b)
end

local function find(self,string_,partial_)
  if not string_ then
    return (self._eos or partial_) and self
  end

  local a,b = split(string_)
  return self._children and self._children[a] and self._children[a]:find(b,partial_)
end

local function traverse(self,path_)
  local format = string.format
  function helper(n,p_)
    if n._eos then
      coroutine.yield(p_)
    end

    for k,v in pairs(n._children or {}) do
      local path = (p_ and #p_>0 and format("%s.%s",p_,k)) or k
      helper(v,path)
    end
  end

  return coroutine.wrap(
    function()
      local root = self
      if path_ then root = self:find(path_,true) end

      if root then helper(root,path_) end
    end)
end


new = function()
  return {
    _children = nil,
    _eos = nil,
    insert = insert,
    find = find,
    traverse = traverse,
         }
end


return {
  new = new
       }