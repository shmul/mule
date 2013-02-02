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
--  assert_equal("cruel",sl[1])
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
--  assert_equal("cruel",sl[1])
--  assert_equal("hello",sl[2])
--  assert_equal("world",sl[3])

  local k = sl:pack()

  sl = skip.new()
  assert_equal(2,sl.maxLevel)
  sl:unpack(k)
  assert_equal(3,sl.maxLevel)
  assert_equal(3,sl.size)
--  assert_equal("cruel",sl[1])
--  assert_equal("hello",sl[2])
--  assert_equal("world",sl[3])
end


function test_next()
  local sl = skip.new()
  for _,v in ipairs({"hello","cruel","world"}) do
    sl:insert(v)
  end

  local f = sl:find("hello")
  assert_equal("hello",f.key)
  assert_equal("world",sl:next(f).key)
  assert_nil(sl:next(sl:next(f)))
end


function test_matching_keys()
  local sl = skip.new()
  for _,v in ipairs({"hello","cruel","world","crueler","crowd"}) do
    sl:insert(v)
  end

  local function matching_keys(prefix_)
    return coroutine.wrap(
      function()
        local find = string.find
        local node = sl:find(prefix_)
        -- first node may not match the prefix
        if node.key<prefix_ then
          node = sl:next(node)
        end
        while node and node.key and find(node.key,prefix_,1,true) do
          coroutine.yield(node)
          node = sl:next(node)
        end
      end)
  end

  local fm = {}
  for i in matching_keys("cru") do
    table.insert(fm,i.key)
  end

  assert_equal(2,#fm)
  assert_equal("cruel",fm[1])
  assert_equal("crueler",fm[2])
end