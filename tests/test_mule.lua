require "mule"
--require "tests.strict"

require "lunit"
module( "test_mule", lunit.testcase, package.seeall )


local function db(p)
  return "./tests/temp/"..p..".tcb"
end

local function new_db(p)
  os.remove(db(p))
  return db(p)
end

function test_create()
  main({ v=false,c="./tests/fixtures/mule.cfg", r=true,d=new_db("test_create")})
  local str = strout("")
  main({ v=false,d=db("test_create"),k="*"},str)
  assert_equal("",str.get_string())

  str = strout("")
  main({ v=false,d=db("test_create"),rest={"./tests/fixtures/judo_add/judo_20101231-225901.mule.20101231-230001.pid-7780.in_work"}},str)
  assert_equal('',str.get_string())

  str = strout("")
  main({ v=false,d=db("test_create"),k="event.risk_score.ingdirect"},str)
  assert_equal('mule_keys({"version": 2,\n"data": ["event.risk_score.ingdirect;1d:3y",\n"event.risk_score.ingdirect;1h:30d",\n"event.risk_score.ingdirect;5m:2d"]\n})',str.get_string())

  str = strout("")
  main({ v=false,d=db("test_create"),rest={"./tests/fixtures/judo_add/judo_20101231-231101.mule.20101231-231201.pid-14025.in_work"}})
  assert_equal('',str.get_string())

  str = strout("")
  main({ v=false,d=db("test_create"),g="event.new_user_identifier.bbvacompass"},str)
  
  -- we have 2 event.new_user_identifier.bbvacompass lines in the 2 processed files
  -- event.new_user_identifier.bbvacompass 2 1293836375
  -- event.new_user_identifier.bbvacompass 1 1293837096
  -- we should calculate the adjusted time stamp and look for it in the output

  local slot1,adj1 = calculate_slot(1293836375,parse_time_unit("5m"),parse_time_unit("2d"))
  local slot2,adj2 = calculate_slot(1293837096,parse_time_unit("5m"),parse_time_unit("2d"))
  assert(string.find(str.get_string(),string.format("%d,1,%d",2,adj1),1,true),adj1)
  assert(string.find(str.get_string(),string.format("%d,1,%d",1,adj2),1,true),adj2)
end

