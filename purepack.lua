module("purepack",package.seeall)
local bit32 = pcall(require,"bit32")

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
                       i%256,
                       fl(i/256)%256,
                       j%256,
                       fl(j/256)%256
                      )
  end

  function from_binary(str_,s)
    s = s or 1
    local by = string.byte
    return (by(str_,1,1) or 0) +
      (by(str_,2,2) or 0)*256 +
      (by(str_,3,3) or 0)*65536 +
      (by(str_,4,4) or 0)*16777216 +
      (by(str_,5,5) or 0)*4294967296 +
      (by(str_,6,6) or 0)*1099511627776
  end
end

local END_OF_TABLE_MARK = "end.of.table.mark"

function pack(obj_)
  local insert = table.insert
  local out = {}

  local function push(type,len,val)
    insert(out,type)
    insert(out,to_binary(len))
    if val then
      insert(out,val)
    end
  end

  if obj_==nil then -- nil and false are NOT the same thing
    insert(out,"l")
  elseif type(obj_)=="string" then
    push("s",#obj_,obj_)
  elseif type(obj_)=="number" then
    push("i",obj_)
  elseif obj_==true or obj_==false then
    insert(out,obj_ and "T" or "F")
  elseif type(obj_)=="table" then
    insert(out,"t")
    for k,v in pairs(obj_) do
      if type(v)~="function" then
        insert(out,pack(k))
        insert(out,pack(v))
      end
    end
    insert(out,"e")
  end
  return table.concat(out,"")
end

local function unpack_helper(str_,i)
  local s = string.sub(str_,i,i)
  i = i + 1
  if s=="l" then
    return nil,i
  end

  local function as_number(u)
    return tonumber(from_binary(string.sub(str_,u)))
  end

  if s=="s" then
    local len = as_number(i)
    return string.sub(str_,i+6,i+5+len),i+len+6
  end
  if s=="i" then
    return as_number(i),i+6
  end
  if s=="T" or s=="F" then
    return s=="T",i
  end
  if s=="e" then
    return END_OF_TABLE_MARK,i
  end
  if s=="t" then
    local t = {}
    local k,v
    repeat
      k,i = unpack_helper(str_,i)
      if k==END_OF_TABLE_MARK then
        return t,i
      end
      v,i = unpack_helper(str_,i)
      t[k] = v
    until i>=#str_
    return t,i
  end
end

function unpack(str_)
  return unpack_helper(str_,1)
end