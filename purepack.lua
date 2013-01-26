module("purepack",package.seeall)
local bit32 = pcall(require,"bit32")

PNS = 6 -- Packed Number Size

if bit32 then
  function to_binary(int_)
    local sh = bit32.arshift
    local an = bit32.band
    local i = sh(int_,16)
    local j = sh(int_,32)
    return string.char(an(int_,255),
                       an(sh(int_,8),255),
                       an(i,255),
                       an(sh(i,16),255),
                       an(j,255),
                       an(sh(j,16),255)
                      )
  end
else
  function to_binary(int_)
    local fl = math.floor
    local i = fl(int_/65536)
    local j = fl(i/65536)
    return string.char(int_%256,
                       fl(int_/256)%256,
                       (i~=0 and i%256) or 0,
                       (i~=0 and fl(i/256)%256) or 0,
                       (j~=0 and j%256) or 0,
                       (j~=0 and fl(j/256)%256) or 0
                      )
  end

  function from_binary(str_,s)
    s = s or 1
    local a,b,c,d,e,f = string.byte(str_,s,s+5)
    return (a or 0) +
      (b and b*256 or 0) +
      (c and c*65536 or 0) +
      (d and d*16777216 or 0) +
      (e and e*4294967296 or 0) +
      (f and f*1099511627776 or 0)
  end
end


local END_OF_TABLE_MARK = "end.of.table.mark"

function pack_helper(obj_,visited_,id_,out)
  local insert = table.insert
  local function push(type,len,val)
    insert(out,type)
    insert(out,to_binary(len))
    if val then
      insert(out,val)
    end
  end

  local function push_value_or_ref(p)
    if not visited_[p] then
      pack_helper(p,visited_,id_,out)
    else
      push("r",visited_[p])
    end
  end

  local function literal(lit_)
    local t = type(lit_)
    if lit_==nil then -- nil and false are NOT the same thing
      insert(out,"l")
      return true
    elseif t=="string" then
      if not visited_[lit_] then
        push("s",#lit_,lit_)
        insert(out,to_binary(id_[1]))
        visited_[lit_] = id_[1]
        id_[1] = id_[1] + 1
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

  if not literal(obj_) and type(obj_)=="table" then
    push("t",id_[1])
    visited_[obj_] = id_[1]
    id_[1] = id_[1] + 1
    for k,v in pairs(obj_) do
      if type(v)~="function" then
        literal(k)
        if not literal(v) then
          push_value_or_ref(v)
        end
      end
    end
    insert(out,"e")
  end
end

function pack(obj_)
  local out = {}
  pack_helper(obj_,{},{0},out)
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