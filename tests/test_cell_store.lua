local c = require "column_db"
local p = require "purepack"
require "tests.strict"

module( "test_cell_store", lunit.testcase,package.seeall )

p.set_pack_lib("bits")
function empty_cell(cell_)
  for i=1,4 do
    if cell_[i] then return false end
  end
  return true
end

function test_read_write()
  local f = clean_test_file("read_write.txt")
  os.remove(f)
  local cs = c.cell_store(f,100,10,4)
  assert_not_nil(cs)
  assert_equal(0,p.from_binary(cs.read(0,0)))
  assert_equal(0,p.from_binary(cs.read(10,9)))

  cs.write(1,1,"hello cruel world")
  cs.flush()
  assert_equal("hell",cs.read(1,1))
  cs.close()
  local cs = c.cell_store(f,100,10,4)
  assert_not_nil(cs)
  assert_true(empty_cell(cs.read(0,0)))
  assert_equal(0,p.from_binary(cs.read(10,9)))
  assert_equal("hell",cs.read(1,1))
end

function test_many_writes()
  local f = clean_test_file("many_writes.txt")
  os.remove(f)
  local cs = c.cell_store(f,100,10,4)
  assert_not_nil(cs)
  for i=1,10 do
    cs.write(i,1,"hello cruel world")
    cs.write(i,0,"world")
  end
  for i=1,10 do
    assert_equal("worl",cs.read(i,0),i)
    assert_equal("hell",cs.read(i,1),i)
  end
end

--verbose_log(true)
