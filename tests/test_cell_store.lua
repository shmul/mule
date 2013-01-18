require "cell_store"
require "tests.strict"

module( "test_cell_store", lunit.testcase,package.seeall )

function empty_cell(cell_)
  for i=1,4 do
    if cell_[i] then return false end
  end
  return true
end

function test_read_write()
  local f = "./tests/temp/read_write.txt"
  os.remove(f)
  local cs = cell_store(f,100,4)
  assert_not_nil(cs)
  assert_nil(cs.read(0,0))
  assert_nil(cs.read(10,10))
  cs.write(1,1,"hello cruel world")
  cs.flush()
  assert_equal("hell",cs.read(1,1))
  cs.close()
  local cs = cell_store(f,100,4)
  assert_not_nil(cs)
  assert_true(empty_cell(cs.read(0,0)))
  assert_nil(cs.read(10,10))
  assert_equal("hell",cs.read(1,1))
end

function test_many_writes()
  local f = "./tests/temp/many_writes.txt"
  os.remove(f)
  local cs = cell_store(f,100,4)
  assert_not_nil(cs)
  for i=1,10 do
    cs.write(1,i,"hello cruel world")
    cs.write(0,i,"world")
  end
  for i=1,10 do
    assert_equal("hell",cs.read(1,i),i)
    assert_equal("worl",cs.read(0,i),i)
  end
end
