local skip = require "skiplist"
require "tests.strict"
require "helpers"

module( "test_skiplist", lunit.testcase,package.seeall )

function test_find()
  local sl = skip.new(10)
  for _,v in ipairs({"hello","cruel","world"}) do
    sl:insert(v)
  end

  assert_equal(3,sl.size)
  assert_equal(3,sl.maxLevel)
  assert_equal("cruel",sl[1])
  assert_equal("cruel",sl["cruel"].value)
  assert_nil(sl["crul"])
  assert_equal("cruel",sl:find("crul").value)
  assert_equal("hello",sl:find("jello").value)
end

function test_pack()
  local sl = skip.new(10)
  for _,v in ipairs({"hello","cruel","world"}) do
    sl:insert(v)
  end
  assert_equal(3,sl.maxLevel)
  local k = sl:pack()

  sl = skip.new(1)
  assert_equal(0,sl.maxLevel)
  sl:unpack(k)
  assert_equal(3,sl.maxLevel)
  assert_equal(3,sl.size)
  assert_equal("cruel",sl[1])
  assert_equal("world",sl[3])
end
