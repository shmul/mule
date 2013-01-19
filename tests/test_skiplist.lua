local skip = require "skiplist"
require "tests.strict"
require "helpers"

module( "test_skiplist", lunit.testcase,package.seeall )

function test_find()
  local sl = skip.new()
  assert_equal(2,sl.maxLevel)
  for _,v in ipairs({"hello","cruel","world"}) do
    sl:insert(v)
  end

  assert_equal(3,sl.size)
  assert_equal(3,sl.maxLevel)
  assert_equal("cruel",sl[1])
  assert_equal("cruel",sl["cruel"].key)
  assert_nil(sl["crul"])
  assert_equal("cruel",sl:find("crul").key)
  assert_equal("hello",sl:find("jello").key)
  for i=1,10 do
    sl:insert(tostring(i))
  end
  assert_equal(13,sl.size)
  assert_equal(5,sl.maxLevel)
end

function test_pack()
  local sl = skip.new()
  for _,v in ipairs({"hello","cruel","world"}) do
    sl:insert(v)
  end
  assert_equal(3,sl.maxLevel)
  assert_equal("cruel",sl[1])
  assert_equal("hello",sl[2])
  assert_equal("world",sl[3])

  local k = sl:pack()

  sl = skip.new()
  assert_equal(2,sl.maxLevel)
  sl:unpack(k)
  assert_equal(3,sl.maxLevel)
  assert_equal(3,sl.size)
  assert_equal("cruel",sl[1])
  assert_equal("hello",sl[2])
  assert_equal("world",sl[3])
end
