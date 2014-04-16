local tr = require "trie"
require "tests.strict"

module( "test_trie", lunit.testcase,package.seeall )

function test_insert()
  local t = tr.new()

  t:insert("hello.cruel.world")
  t:insert("hello.crueler.world")
  t:insert("hello.world")
  t:insert("bye.bye")
  t:insert("ciao")
  assert_equal(5,t:size())
  assert(t:find("ciao"))
  assert(t:find("bye.bye"))
  assert_nil(t:find("bye"))
  assert(t:find("bye",true))
  assert_equal(1,t:find("bye",true):size())
  assert(t:find("hello.cruel.world"))
  assert_equal(1,t:find("hello.cruel",true):size())
  assert_equal(0,t:find("hello.cruel.world"):size())
  assert_nil(t:find("hello.goodbye"))
  assert_nil(t:find("hello.crueler"))
  assert(t:find("hello.crueler.world"))
  assert_nil(t:find("hellocrueler.world"))
  assert_nil(t:find("hello.crueler.worldblue"))
  assert_nil(t:find("hello.crueler.world.blue"))

end

function test_traverse()
  local t = tr.new()
  local keys = {
    "hello.cruel.world",
    "hello.crueler.world",
    "hello.world",
    "bye.bye",
    "ciao"
  }


  local visited = {}
  for _,v in ipairs(keys) do
    visited[v] = false
    t:insert(v)
  end

  local count = 0
  for k,_ in t:traverse() do
    count = count + 1
    visited[k] = true
  end

  assert_equal(#keys,count)
  for _,v in ipairs(keys) do
    assert(visited[v],v)
  end

  count = 0
  for k,_ in t:traverse("") do
    count = count + 1
  end
  assert_equal(5,count)

  count = 0
  for k,_ in t:traverse("hello") do
    count = count + 1
  end
  assert_equal(3,count)

  count = 0
  for k,_ in t:traverse("hello",nil,nil,0) do
    count = count + 1
  end
  assert_equal(0,count)

  count = 0
  for k,_ in t:traverse("hello",nil,nil,1) do
    count = count + 1
  end
  assert_equal(1,count)

  count = 0
  for k,_ in t:traverse("hello.cruel") do
    count = count + 1
  end
  assert_equal(1,count)

  count = 0
  for k,_ in t:traverse("hello.cruel",nil,nil,1) do
    count = count + 1
  end
  assert_equal(1,count)

  count = 0
  for k,_ in t:traverse("hello",nil,nil,2) do
    count = count + 1
  end
  assert_equal(3,count)

  count = 0
  for k,_ in t:traverse("hello.cruel",nil,nil,0) do
    count = count + 1
  end
  assert_equal(0,count)

  count = 0
  for k,_ in t:traverse("hola") do
    count = count + 1
  end
  assert_equal(0,count)
end


function test_inner_traverse()
  local t = tr.new()
  local keys = {
    "hello.cruel.world",
    "hello.crueler.world",
    "hello.world",
    "bye.bye",
    "ciao"
  }

  local visited = {}
  for _,v in ipairs(keys) do
    visited[v] = false
    t:insert(v)
  end


  local count = 0
  assert(t:find("hello.cruel",true))
  for k in t:find("hello.cruel",true):traverse() do
    count = count + 1
  end
  assert_equal(1,count)

  count = 0
  for k in t:traverse("hello.cruel") do
    count = count + 1
  end
  assert_equal(1,count)

end

function test_prefix_find()
  local t = tr.new()
  t:insert("hello.cruel.world")
  t:insert("hello.crueler.world")
  t:insert("hello.world")
  t:insert("bye.bye")
  t:insert("ciao")

  assert(t:find("hell",true,true))
  assert_nil(t:find("hell",true,false))
  assert(t:find("hello",true,false))
end

function test_pack()
  local t = tr.new()
  t:insert("hello.cruel.world")
  t:insert("hello.crueler.world")
  t:insert("hello.world")
  t:insert("bye.bye")
  t:insert("ciao")

  local a = t:pack()
  local u = tr.unpack(a)
  assert(u:find("hello",true,false))
  assert_equal(5,u:size())
end


function test_delete()
  local t = tr.new()
  t:insert("hello.cruel.world")
  t:insert("hello.crueler.world")
  t:insert("hello.world")
  t:insert("bye.bye")
  t:insert("ciao")

  t:delete("ciao")
  assert_equal(4,t:size())
  t:delete("bye",true)
  assert_equal(3,t:size())
  t:delete("hell",true,true)
  assert_equal(0,t:size())
end