
require "tests.strict"

local lunit = require "lunit"
if _VERSION >= 'Lua 5.2' then
  _ENV = lunit.module('test_mule','seeall')
else
  module( "test_mule", lunit.testcase, package.seeall )
end

pcall(require, "profiler")
require "mule"

local function db(p)
  return test_directory()..p.."_mdb"
end

local function new_db(p)
  create_test_directory(p.."_mdb")
  return db(p)
end

function test_create()
  main({ v=false,c="./tests/fixtures/mule.cfg", r=true,f=true,d=new_db("test_create")})

  local str = strout("")
  main({ v=false,d=db("test_create"),rest = {".key *"}},str)
  assert(string.find(str.get_string(),'"data": {}',1,true))
  str = strout("")
  main({ v=false,y=false,d=db("test_create"),rest={"./tests/fixtures/input1.mule"}},str)
  assert_equal('true',str.get_string())
  main({ v=false,d=db("test_create"),g="beer.stout.irish"},str)

  str = strout("")
  main({ v=false,d=db("test_create"),rest = {".key beer.ale"}},str)
  assert_equal(weak_hash('{"version": 3,\n"data": {"beer.ale;1d:3y": {"children": true},"beer.ale;1h:30d": {"children": true},"beer.ale;5m:2d": {"children": true}}\n}'),weak_hash(str.get_string()))

  str = strout("")
  main({ v=false,d=db("test_create"),rest={"./tests/fixtures/input2.mule"}},str)
  assert_equal('true',str.get_string())

  str = strout("")
  main({ v=false,d=db("test_create"),rest ={".graph beer.stout.irish"}},str)

  -- we have 2 beer.stout.irish lines in the 2 processed files
  -- beer.stout.irish 2 1293836375
  -- beer.stout.irish 1 1293837096
  -- we should calculate the adjusted time stamp and look for it in the output

  local slot1,adj1 = calculate_idx(1293836375,parse_time_unit("5m"),parse_time_unit("2d"))
  local slot2,adj2 = calculate_idx(1293837096,parse_time_unit("5m"),parse_time_unit("2d"))
  assert(string.find(str.get_string(),string.format("%d,1,%d",2,adj1),1,true),adj1)
  assert(string.find(str.get_string(),string.format("%d,1,%d",1,adj2),1,true),adj2)
end

function test_first_files()
  os.execute("rm -rf tests/temp/first_files")
  os.execute("mkdir -p tests/temp/first_files")
  for i=0,9 do
    os.execute("touch tests/temp/first_files/"..i..".foo")
    os.execute("touch tests/temp/first_files/"..i..".bar")
  end
  local count = 0
  for f in first_files("tests/temp/first_files","%.foo$",4) do
    count = count + 1
    assert(string.find(f,"%.foo$"))
  end
  assert_equal(4,count)

  count = 0
  for f in first_files("tests/temp/first_files","%.bar",40) do
    count = count + 1
    assert(string.find(f,"%.bar"))
  end
  assert_equal(10,count)

  count = 0
  for f in first_files("tests/temp/first_files","%.snark",1) do
    count = count + 1
  end
  assert_equal(0,count)

end

--verbose_log(true)
--profiler.start("profiler.out")
