module("purepack",package.seeall)

local END_OF_TABLE_MARK = "end.of.table.mark"

function pack(obj_)
  local insert = table.insert
  local format = string.format
  local out = {}

  local function push(type,len,val)
    insert(out,type)
    insert(out,format("%08x",len))
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
      insert(out,pack(k))
      insert(out,pack(v))
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
    return tonumber(string.format("0x%s",string.sub(str_,u,u+7)))
  end

  if s=="s" then
    local len = as_number(i)
    return string.sub(str_,i+8,i+len+7),i+len+8
  end
  if s=="i" then
    return as_number(i),i+8
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