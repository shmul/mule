module("purepack",package.seeall)
local bit32_found,bit32 = pcall(require,"bit32")
local lpack,_ = pcall(require,"pack")

PNS = 4 -- Packed Number Size

if bit32_found then
  function to_binary(int_)
    local sh = bit32.rshift
    local an = bit32.band
    local i = sh(int_,16)
    return string.char(an(sh(i,8),255),
                       an(i,255),
                       an(sh(int_,8),255),
                       an(int_,255))
  end

  function from_binary(str_,s)
    s = s or 1
    local a,b,c,d = string.byte(str_,s,s+3)
    local sh = bit32.lshift
    return (d or 0) +
      (c and sh(c,8) or 0) +
      (b and sh(b,16) or 0) +
      (a and sh(a,24) or 0)
  end

elseif lpack then
  function to_binary(int_)
    return string.pack(">I",int_)
  end
  function from_binary(str_,s)
    local _,value = string.unpack(str_,">I",s or 1)
    return value
  end

else
  function to_binary(int_)
    local fl = math.floor
    local i = fl(int_/65536)
    return string.char((i~=0 and fl(i/256)%256) or 0,
                       (i~=0 and i%256) or 0,
                       fl(int_/256)%256,
                       int_%256)
  end

  function from_binary(str_,s)
    s = s or 1
    local a,b,c,d = string.byte(str_,s,s+3)
    return (d or 0) +
      (c and c*256 or 0) +
      (b and b*65536 or 0) +
      (a and a*16777216 or 0)
  end
end


local END_OF_TABLE_MARK = "end.of.table.mark"

-- for some reason using coroutines rather than standard functions seems slightly
-- faster. Perhaps the profiler distorts the real picture ?
function pack_helper(obj_,visited_,id_,out)
  local insert = table.insert
  local yield = coroutine.yield

  local push = coroutine.wrap(function(type,len,val)
                                while true do
                                  insert(out,type)
                                  insert(out,to_binary(len))
                                  if val then
                                    insert(out,val)
                                  end
                                  type,len,val = yield(true)
                                end
                              end)
--[[
  local function push(type,len,val)
    insert(out,type)
    insert(out,to_binary(len))
    if val then
      insert(out,val)
    end
    return true
  end
  --]]

  local literal = coroutine.wrap(
    function(lit_)
      while true do
        local t = type(lit_)
        if lit_==nil then -- nil and false are NOT the same thing
          insert(out,"l")
          lit_ = yield(true)
        elseif t=="string" then
          if not visited_[lit_] then
            push("s",#lit_,lit_)
            insert(out,to_binary(id_))
            visited_[lit_] = id_
            id_ = id_ + 1
          else
            push("r",visited_[lit_])
          end
          lit_ = yield(true)
        elseif t=="number" then
          push("i",lit_)
          lit_ = yield(true)
        elseif lit_==true or lit_==false then
          insert(out,lit_ and "T" or "F")
          lit_ = yield(true)
        else
          lit_ = yield(false)
        end
      end
    end)
--[[
    local function literal(lit_)
      local t = type(lit_)
      if lit_==nil then -- nil and false are NOT the same thing
        insert(out,"l")
        return true
      elseif t=="string" then
        if not visited_[lit_] then
          push("s",#lit_,lit_)
          insert(out,to_binary(id_))
          visited_[lit_] = id_
          id_ = id_ + 1
        else
          push("r",visited_[lit_])
        end
        return true
      elseif t=="number" then
        push("i",lit_)
        return true
      elseif lit_==true or lit_==false then
        insert(out,lit_ and "T" or "F")
        return true
      end
      return false
    end
  --]]

  local function helper(o_)
    if not literal(o_) and type(o_)=="table" then
      push("t",id_)
      visited_[o_] = id_
      id_ = id_ + 1
      for k,v in pairs(o_) do
        if type(v)~="function" then
          literal(k)
          local _ = literal(v) or (visited_[v] and push("r",visited_[v])) or helper(v)
        end
      end
      insert(out,"e")
    end
  end

  helper(obj_)
end

function pack(obj_)
  local out = {}
  pack_helper(obj_,{},0,out)
  return table.concat(out,"")
end

local function unpack_helper(str_,i,visited_)
  local s = string.sub(str_,i,i)

  i = i + 1
  if s=="l" then
    return nil,i
  end

  if s=="s" then
    local len = from_binary(str_,i)
    local f = i+PNS
    local e = f+len
    local str = string.sub(str_,f,e-1)
    local id = from_binary(str_,e)
    visited_[id] = str
    return str,e+PNS
  end
  if s=="i" then
    return from_binary(str_,i),i+PNS
  end
  if s=="r" then
    return visited_[from_binary(str_,i)],i+PNS
  end
  if s=="T" or s=="F" then
    return s=="T",i
  end
  if s=="e" then
    return END_OF_TABLE_MARK,i
  end
  local e = #str_
  if s=="t" then
    local t = {}
    local k,v
    visited_[from_binary(str_,i)] = t
    i = i + PNS
    repeat
      k,i = unpack_helper(str_,i,visited_)
      if k==END_OF_TABLE_MARK then
        return t,i
      end
      v,i = unpack_helper(str_,i,visited_)
      t[k] = v
    until i>=e
    return t,i
  end
end

function unpack(str_)
  return unpack_helper(str_,1,{})
end