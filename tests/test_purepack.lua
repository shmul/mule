local p = require "purepack"
require "tests.strict"
require "helpers"

module( "test_purepack", lunit.testcase,package.seeall )
p.set_pack_lib("purepack")

local function for_each_lib(func_)
  for _,v in ipairs({"lpack","bit","purepack"}) do
    p.set_pack_lib(v)
    func_()
  end
end

local function upp(obj_)
  return p.unpack(p.pack(obj_))
end

function test_literals()
  function helper()
    assert_equal("l",p.pack(nil))
    assert_equal(nil,upp(nil))
    assert_equal(1,upp(1))
    assert_equal(1,upp(1))
    assert_equal(301298,upp(301298))
    assert_equal(math.abs(2^31),math.abs(upp(2^31)))
    --  assert_equal(2^32,upp(2^32))
    --  assert_equal(2^33,upp(2^33))
    --  assert_equal(2^35,upp(2^35))
    assert_equal(true,upp(true))
    assert_equal(false,upp(false))
    assert_equal("true",upp("true"))
    assert_equal("false",upp("false"))
    assert_equal("whathaveyou",upp("whathaveyou"))

    local longstring = [[
Dark star crashes, pouring it's light into ashes.
Reason tatters, the forces tear loose from the axis.
Searchlight casting for faults in the clouds of delusion.
Shall we go, you and I while we can
Through the transitive nightfall of diamonds?

Mirror shatters in formless reflections of matter.
Glass hand dissolving to ice petal flowers revolving.
Lady in velvet recedes in the nights of good-bye.
Shall we go, you and I while we can
Through the transitive nightfall of diamonds?
]]
   assert_equal(longstring,upp(longstring))
  end
  for_each_lib(helper)
end

local function compare_tables(left,right)
  local function contains(a,b)
    for k,v in pairs(a) do
      local eq = type(b[k])=="table" and compare_tables(b[k],v) or b[k]==v
      if not eq then return false end
    end
    return true
  end
  return contains(left,right) and contains(right,left)
end

function test_tables()
  local function helper()
    assert(compare_tables({},upp({})))
    assert(compare_tables({1,2},upp({1,2})))
    assert(compare_tables({"a","4",1},upp({"a","4",1})))
    assert(compare_tables({true,"4",1,false},upp({true,"4",1,false})))
    assert(compare_tables({hello="world"},upp({hello="world"})))

    local t = {version = 3,
               data = {"beer.ale.pale;1d:3y","beer.ale.pale;1h:30d","beer.ale.pale;5m:2d"}
    }

    assert(compare_tables(t,upp(t)))
  end
  for_each_lib(helper)
end

function test_table_of_arrays()
  local function helper()
    local t = {beer = {{"300","172800"},{"3600","2592000"},{"86400","94608000"}},
               wine = {{"300","172800"},{"3600","2592000"},{"86400","94608000"}}
    }
    assert(compare_tables(t,upp(t)))
  end
  for_each_lib(helper)
end

function test_binary()
  local function helper()
    local tests = {0, 10, 8, 256, 65536, 16777216,math.pow(2,31)-1}--,math.pow(2,48)-1}
    for i,v in ipairs(tests) do
      assert_equal(v,p.from_binary(p.to_binary(v)),i)
    end
  end
  for_each_lib(helper)
end

function test_binary3()
  local function helper()
    local tests = {{0, 10, 8}, {256, 65536, 16777216}}
    for i,v in ipairs(tests) do
      local a,b,c = p.from_binary3(p.to_binary3(unpack(v)))
      assert_equal(v[1],a,i)
      assert_equal(v[2],b,i)
      assert_equal(v[3],c,i)
    end
  end
  for_each_lib(helper)
end

function test_circular()
  local function helper()
    local a = { val = 1 }
    local b = { val = 2 }
    local c = { val = 3 }
    a.next = b
    a.double_next = c
    b.next = c
    c.next = a

    local v = upp(a)
    assert_equal(v,v.next.next.next)
    assert_equal(2,v.next.val)
    assert_equal(3,v.next.next.val)
    assert_equal(3,v.double_next.val)
  end
  for_each_lib(helper)
end

function test_string_concat()
  function helper()
    assert_equal("",p.concat_three_strings())
    assert_equal("hellocruelworld",p.concat_three_strings("hello","cruel","world"))
    assert_equal("helloworld",p.concat_three_strings("hello","","world"))
  end
  for_each_lib(helper)
end