require "mulelib"
require "tests.strict"
pcall(require, "profiler")
require "lunit"
require "tc_store"
require "memory_store"
local cdb = require "column_db"

module( "test_mulelib", lunit.testcase,package.seeall )


local function cabinet_db_factory(name_)
  os.remove(name_..cabinet.suffix)
  return cabinet_db(name_..cabinet.suffix)
end

local function column_db_factory(name_)
  os.execute("rm -rf "..name_.."_cdb")
  os.execute("mkdir -p "..name_.."_cdb")
  return cdb.column_db(name_.."_cdb")
end

local function for_each_db(name_,func_,no_mule_)
  local dbs = {in_memory_db(),
               column_db_factory(name_)}
  if cabinet then
    table.insert(dbs,cabinet_db_factory(name_))
  end

  for _,db in ipairs(dbs) do
    func_(no_mule_ and db or mule(db))
  end
end

local function insert_all_args(tbl_)
  return function(...)
    for _,v in ipairs({...}) do
      table.insert(tbl_,v)
    end
         end
end

local function print_all_args(...)
  print(...)
end

function test_parse_time_unit()
  local tests = {
	{0,""},
	{0,"1sd"},
	{0,"d"},
	{0," 1s"},
	{0,"1s_"},
	{1,"1s"},
	{1,"1"},
	{60,"1m"}, -- minute
	{2*3600*24,"2d"},
	{7*3600*24*365,"7y"},
	{3600,"3600"},
  }
  for i,v in ipairs(tests) do
	assert_equal(v[1],parse_time_unit(v[2]),i)
  end


  tests = {
	{7*3600*24*365,"7y"},
	{60,"1m"},
	{2*3600*24,"2d"},
	{7*3600*24,"1w"},
	{14*3600*24,"2w"},
  }

  for i,v in ipairs(tests) do
	assert_equal(v[2],secs_to_time_unit(v[1]),i)
  end
end


function test_string_lines()
  local str = "hello\ncruel\nworld"
  local lines = {}
  for i in string_lines(str) do
	table.insert(lines,i)
  end

  assert_equal(lines[1],"hello")
  assert_equal(lines[2],"cruel")
  assert_equal(lines[3],"world")

end

function test_calculate_idx()
  local tests = {
	-- {step,period,timestamp,slot,adjust}
	{1,60,0,0,0},
	{1,60,60,0,60},
	{2,60,61,0,60},
	{2,60,121,0,120},
	{2,60,121,0,120},
	{2,60,123,1,122},
    {300,2*24*60*60,1293836375,275,1293836100}
  }

  for i,t in ipairs(tests) do
	local slot,adjusted = calculate_idx(t[3],t[1],t[2])
	assert_equal(t[4],slot,i)
	assert_equal(t[5],adjusted,i)
  end
end

function helper_time_sequence(db_)
  local step,period = parse_time_pair("1m:60m")
  assert_equal(60,step)
  assert_equal(3600,period)

  local seq = sequence(db_,"seq;1m:60m")
  assert_equal(0,seq.slot_index(0))
  assert_equal(0,seq.slot_index(59))
  assert_equal(1,seq.slot_index(60))
  assert_equal(5,seq.slot_index(359))
  assert_equal(6,seq.slot_index(360))

  seq.update(0,10)
  assert_equal(10,seq.slot(0)._sum)
  assert_equal(10,seq.slot(seq.latest())._sum)
  seq.update(1,17,1)
  assert_equal(27,seq.slot(0)._sum)
  assert_equal(2,seq.slot(0)._hits)
  assert_equal(27,seq.slot(seq.latest())._sum)
  seq.update(3660,3,1)
  assert_equal(3,seq.slot(1)._sum)
  assert_equal(3,seq.slot(seq.latest())._sum)
  seq.update(60,7,1) -- this is in the past and should be discarded
  assert_equal(3,seq.slot(1)._sum)
  assert_equal(1,seq.slot(1)._hits)
  assert_equal(3,seq.slot(seq.latest())._sum)
  seq.update(7260,89,1)
  assert_equal(89,seq.slot(1)._sum)
  assert_equal(1,seq.slot(1)._hits)
  assert_equal(89,seq.slot(seq.latest())._sum)

  --seq.serialize(stdout(", "))
  local tbl = {}
  seq.serialize({deep=true},insert_all_args(tbl),insert_all_args(tbl))
  assert_equal("seq",tbl[1])
  assert_equal(60,tbl[2]) --
  assert_equal(3600,tbl[3]) -- period

  -- first slot
  assert_equal(27,tbl[4])
  assert_equal(2,tbl[5])
  assert_equal(0,tbl[6])
  -- second slot
  assert_equal(89,tbl[7])
  assert_equal(1,tbl[8])
  assert_equal(7260,tbl[9])
  -- third slot
  assert_equal(0,tbl[10])
  assert_equal(0,tbl[11])
  assert_equal(0,tbl[12])

--[[
  local seq1 = sequence(db_,"seq")
  local tblin = tablein(tbl)
  local function read_3_values()
    return tblin.read(),tblin.read(),tblin.read()
  end

  assert_equal("seq",seq1.deserialize(in_memory_db,true,read_3_values,read_3_values))
  --]]
  local tbl1 = {}
  seq.serialize({deep=true},insert_all_args(tbl1),insert_all_args(tbl1))
  for i,v in ipairs(tbl) do
	assert_equal(v,tbl1[i],i)
  end

  seq.update(10799,43,1)
  assert_equal(43,seq.slot(59)._sum)
  assert_equal(1,seq.slot(59)._hits)

  seq.update(10800,99,1)
  assert_equal(99,seq.slot(0)._sum)
  assert_equal(1,seq.slot(0)._hits)

  tbl = {}
  seq.serialize({sorted=true,deep=true},insert_all_args(tbl),insert_all_args(tbl))

  assert_equal("seq",tbl[1])
  assert_equal(60,tbl[2])
  assert_equal(3600,tbl[3]) -- period

  -- last slot
  local last = 183
  assert_equal(99,tbl[last-2])
  assert_equal(1,tbl[last-1])
  assert_equal(10800,tbl[last-0])
  -- one before last slot
  assert_equal(43,tbl[last-5])
  assert_equal(1,tbl[last-4])
  assert_equal(10740,tbl[last-3])

end

function test_to_timestamp()
  local tests = {
	-- {expr_,now,latest,expected}
	{"1",60,0,1},
	{"1+2",60,10,3},
	{"print(1+2)",60,10,nil},
	{"now+2",60,10,62},
	{"latest-7",60,10,3},
	{"latest-1m",60,120,60},
	{"now + latest - 1m",61,121,122},
	{"1..",60,0,nil},
	{"1..2",60,0,{1,2}},
	{"31..2",60,0,{31,2}},
	{"now + latest - 1m..1",61,121,{122,1}},
	{"latest-1m..latest-1m",60,120,{60,60}},
  }

  for i,t in ipairs(tests) do
	local ts = to_timestamp(t[1],t[2],t[3])
	if ts and type(t[4])=="table" then
	  assert_equal(t[4][1],ts[1],i)
	  assert_equal(t[4][2],ts[2],i)
	else
	  assert_equal(t[4],ts,i)
	end
  end

end


function test_sequences()
  for_each_db("./tests/temp/test_sequences",helper_time_sequence,true)
end

local function table_itr(tbl_)
  local current = 0
  return function()
		   current = current + 1
		   return tbl_[current]
		 end
end

function test_remove_comment()
  assert_equal("",remove_comment(""))
  assert_equal("",remove_comment("# hello"))
  assert_equal("",remove_comment("    # hello"))
  assert_equal("",remove_comment("    # hello"))
  assert_equal("hello cruel",remove_comment("hello cruel #world"))
  assert_equal("hello cruel",remove_comment("	hello cruel #world"))
  assert_equal("hello cruel",remove_comment("  hello cruel #world"))
end

function test_parse_input_line()
  local items = parse_input_line("beer.ale 60S:12H 1H:30d")
  assert_equal(3,#items)
  assert_equal("beer.ale",items[1])
end

function test_factories()
  local m = mule(in_memory_db())
  m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.ale 60s:24h"}))

  assert_equal(3,#m.get_factories()["beer.ale"])
  local factories = m.get_factories()
  assert(factories["beer.ale"])
  assert_equal(0,#m.matching_sequences("beer.ale"))
  assert_equal(0,#m.matching_sequences("beer.ale.brown.newcastle"))

  m.process("beer.ale.brown.newcastle 20 74857843")
  assert_equal(9,#m.matching_sequences("beer.ale"))
  assert_equal(6,#m.matching_sequences("beer.ale.brown"))
  assert_equal(3,#m.matching_sequences("beer.ale.brown.newcastle"))
  assert_equal(0,#m.matching_sequences("beer.ale.pale"))

  m.process("beer.ale.belgian.trappist 70 56920123")
  assert_equal(15,#m.matching_sequences("beer.ale"))

  m.process("beer.ale.belgian.trappist 99 62910121")
  assert_equal(15,#m.matching_sequences("beer.ale"))

end

function test_modify_factories_1()
  local m = mule(in_memory_db())
  m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.ale 60s:24h"}))

  assert_equal(3,#m.get_factories()["beer.ale"])

  m.modify_factories({{"beer.ale","1h:30d","2h:90d"}})
  assert_equal(3,#m.get_factories()["beer.ale"])
  local factories = m.get_factories()
  assert(factories["beer.ale"])
  -- first retention 60s:12h
  assert_equal(60,factories["beer.ale"][1][1])
  assert_equal(12*60*60,factories["beer.ale"][1][2])
  -- second retention is new 2h:90d
  assert_equal(2*60*60,factories["beer.ale"][2][1])
  assert_equal(90*24*60*60,factories["beer.ale"][2][2])

end

local function sequence_any(seq_,callback_)
  local out = {}

  seq_.serialize({deep=true},insert_all_args(out),insert_all_args(out))
  local count = 1
  for i,v in ipairs(out) do
	if i>6 then -- first 3 slots are the header
	  if callback_(v) then return true end
	end
  end

  return false
end

local function empty_sequence(seq_)
  local rv = sequence_any(seq_,function(v) return v~=0 end)
  return not rv
end

local function non_empty_sequence(seq_)
  local rv = sequence_any(seq_,function(v) return v>0 end)
  return rv
end

local function empty_metrics(metrics_)
  for _,m in ipairs(metrics_ or {}) do
	if not empty_sequence(m) then return false end
  end
  return true
end


local function non_empty_metrics(metrics_)
  if not metrics_ then return false end
  for _,m in ipairs(metrics_) do
	if non_empty_sequence(m) then return true end
  end
  return false
end

local function dump_metrics(metrics_)
  if not metrics_ then return end
  for i,m in ipairs(metrics_) do
	m.serialize(stdout(", "))
  end
end

function test_metric_hierarchy()
  local ms = metric_hierarchy("foo")
  assert_equal("foo",ms())
  assert_equal(nil,ms())

  ms = metric_hierarchy("foo.bar")
  assert_equal("foo",ms())
  assert_equal("foo.bar",ms())
  assert_equal(nil,ms())

  ms = metric_hierarchy("foo.bar.snark")
  assert_equal("foo",ms())
  assert_equal("foo.bar",ms())
  assert_equal("foo.bar.snark",ms())
  assert_equal(nil,ms())
end

function test_process_in_memory()
  local db = in_memory_db()
  local m = mule(db)
  m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))

  assert_equal(0,#m.matching_sequences("beer.ale"))
  local factories = m.get_factories()
  assert(factories["beer.ale"])
  assert(factories["beer.stout"])
  assert(not factories["beer.lager"])
  assert_equal(1,#factories["beer.stout"])
  assert_equal(2,#factories["beer.ale"])
  assert_equal(nil,factories["beer.ale.brown.newcastle"])

  m.process("beer.ale.mild 20 74857843")

  assert(empty_metrics(m.matching_sequences("beer.stout")))

  assert(empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))

  assert(non_empty_metrics(m.matching_sequences("beer.ale.mild")))

  m.process("beer.ale.brown.newcastle 98 74857954")
  assert(m.matching_sequences("beer.ale.brown.newcastle"))
  assert(non_empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))

  m.process("beer.stout.irish 98 74857954")
  assert(non_empty_metrics(m.matching_sequences("beer.stout.irish")))
  assert(non_empty_metrics(m.matching_sequences("beer.stout")))
  assert(empty_metrics(m.matching_sequences("beer.wheat")))


  m.process("beer.stout 143 74858731")
  assert(non_empty_metrics(m.matching_sequences("beer.stout")))
end

function test_top_level_factories()

  function helper(m)
	m.configure(table_itr({"beer. 60s:12h 1h:30d","beer 3m:1h"}))
	assert_equal(0,#m.matching_sequences("beer.ale"))
	local factories = m.get_factories()
	assert_equal(1,table_size(factories))
	assert(factories["beer"])
	assert(not factories["beer.lager"])
	assert_equal(nil,factories["beer.ale"])
	assert_equal(nil,factories["beer.ale.brown.newcastle"])


    m.process({"beer.ale.mild 20 74857843","beer.ale.mild.bitter 20 74857843","beer.ale.mild.sweet 30 74857843"})

	assert(empty_metrics(m.matching_sequences("beer.stout")))

	assert(empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))
	assert(non_empty_metrics(m.matching_sequences("beer")))
	assert(non_empty_metrics(m.matching_sequences("beer.ale")))
	assert(non_empty_metrics(m.matching_sequences("beer.ale.mild")))
	assert(string.find(m.latest("beer"),"20,1,74857800"))

	m.process("beer.ale.brown.newcastle 98 74857954")
	assert(m.matching_sequences("beer.ale.brown.newcastle"))
	assert(non_empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))

	m.process("beer.stout.irish 98 74857954")
	assert(non_empty_metrics(m.matching_sequences("beer.stout.irish")))
	assert(non_empty_metrics(m.matching_sequences("beer.stout")))
	assert(empty_metrics(m.matching_sequences("beer.wheat")))


	m.process("beer.stout 143 74858731")
	assert(non_empty_metrics(m.matching_sequences("beer.stout")))
  end

  for_each_db("./tests/temp/top_level",helper)
end

function helper_modify_factories(m)
  m.configure(table_itr({"beer.ale 60s:12h 1h:30d"}))

  m.process("beer.ale.mild 20 74857843")
  assert(non_empty_metrics(m.matching_sequences("beer.ale")))

  assert_equal(4,#m.matching_sequences("beer.ale"))
  assert(string.find(m.graph("beer.ale"),'"beer.ale;1m:12h": [[20,1,74857800]'))
  assert(string.find(m.graph("beer.ale"),'"beer.ale;1h:30d": [[20,1,74857800]'))
  m.modify_factories({{"beer.ale","1h:30d","2h:90d"}})

  assert(non_empty_metrics(m.matching_sequences("beer.ale")))
  assert_nil(string.find(m.graph("beer.ale"),'"beer.ale;1h:30d": [[20,1,74857800]'))
  assert(string.find(m.graph("beer.ale"),'"beer.ale;2h:90d": [[20,1,74857800]'))
end

function test_modify_factories_2()
  helper_modify_factories(mule(in_memory_db()))
end

function test_modify_factories_3()
  for_each_db("./tests/temp/modify_factories",helper_modify_factories)
end


function test_reset()
  function helper(m)
	m.configure(table_itr({"beer 60s:12h 1h:30d","beer.stout 3m:1h"}))
	assert_equal(0,#m.matching_sequences("beer.ale"))
	local factories = m.get_factories()
	assert(factories["beer.stout"])

	assert_equal(0,#m.matching_sequences("beer.stout"))
	assert_equal(0,#m.matching_sequences("beer.ale.brown.newcastle"))

	m.process("beer.ale.mild 20 74857843")

	assert(non_empty_metrics(m.matching_sequences("beer")))
	assert(empty_metrics(m.matching_sequences("beer.stout")))
	assert(2,#m.matching_sequences("beer.ale"))
	assert(2,#m.matching_sequences("beer.ale.mild"))

	assert(empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))
	assert(non_empty_metrics(m.matching_sequences("beer.ale.mild")))

	m.process("beer.ale.brown.newcastle 98 74857954")
	assert(m.matching_sequences("beer.ale.brown.newcastle"))
	assert(non_empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))

	m.process("beer.stout.irish 98 74857954")
	assert(non_empty_metrics(m.matching_sequences("beer.stout.irish")))
	assert(non_empty_metrics(m.matching_sequences("beer.stout")))


	m.process("beer.stout 143 74858731")
	assert(non_empty_metrics(m.matching_sequences("beer.stout")))
	assert(non_empty_metrics(m.matching_sequences("beer")))

	m.process(".reset beer.stout")
	assert(non_empty_metrics(m.matching_sequences("beer")))

	assert(empty_metrics(m.matching_sequences("beer.stout")))
	assert(empty_metrics(m.matching_sequences("beer.ale.irish")))
	assert(non_empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))


	m.process(".reset beer.ale")
	assert(non_empty_metrics(m.matching_sequences("beer")))
	assert(empty_metrics(m.matching_sequences("beer.ale")))
	assert(empty_metrics(m.matching_sequences("beer.ale.brown")))
	assert(empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))
  end


  for_each_db("./tests/temp/reset",helper)
end

function test_save_load()
  local db = in_memory_db()
  local m = mule(db)

  m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h"}))
  assert_equal(2,table_size(m.get_factories()))
  m.process("beer.ale.mild 20 74857843")
  m.process("beer.ale.brown.newcastle 98 74857954")
  m.process("beer.stout.irish 98 74857954")
  m.process("beer.stout 143 74858731")
  m.save()

  local n = mule(db)
  n.load()
  assert_equal(2,table_size(n.get_factories()))
  assert_equal(2,#n.get_factories()["beer.ale"])
  assert_equal(1,#n.get_factories()["beer.stout"])
end


function test_process_other_dbs()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))
    assert_equal(0,#m.matching_sequences("beer.ale"))
    local factories = m.get_factories()
    assert(factories["beer.ale"])
    assert(factories["beer.stout"])
    assert(not factories["beer.lager"])
    assert_equal(1,#factories["beer.stout"])
    assert_equal(2,#factories["beer.ale"])
    assert_equal(nil,factories["beer.ale.brown.newcastle"])

    m.process("beer.ale.mild 20 74857843")

    assert(empty_metrics(m.matching_sequences("beer.stout")))

    assert(empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))
    assert(non_empty_metrics(m.matching_sequences("beer.ale.mild")))

    m.process("beer.ale.brown.newcastle 98 74857954")
    assert(m.matching_sequences("beer.ale.brown.newcastle"))
    assert(non_empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))

    m.process("beer.stout.irish 98 74857954")
    assert(non_empty_metrics(m.matching_sequences("beer.stout.irish")))
    assert(non_empty_metrics(m.matching_sequences("beer.stout")))
    assert(empty_metrics(m.matching_sequences("beer.wheat")))


    m.process("beer.stout 143 74858731")
    assert(non_empty_metrics(m.matching_sequences("beer.stout")))
  end
  for_each_db("./tests/temp/process_tokyo",helper)
end

function test_latest()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))

    m.process("beer.ale.brown 3 3")
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"3,1,0"))
    assert(string.find(m.graph("beer.ale.brown;1m:12h","latest"),"3,1,0"))
    assert(string.find(m.slot("beer.ale.brown;1m:12h",{timestamp="1"}),"3,1,0"))
    assert(string.find(m.latest("beer.ale.pale;1m:12h"),'"data": {}'))
    assert(string.find(m.graph("beer.ale.pale;1m:12h","latest"),'"data": {"beer.ale.pale;1m:12h": []',1,true))
    assert(string.find(m.latest("beer.ale.pale;1h:30d"),'"data": {}'))


    -- the timestamp is adjusted
    assert(string.find(m.latest("beer.ale.brown"),"3,1,0"))
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"3,1,0"))


    m.process("beer.ale.pale 2 3601")
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"3,1,0"))
    assert(string.find(m.graph("beer.ale.brown;1m:12h",{timestamp="latest-90"}),"0,0,0"))
    assert(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="3604"}),"2,1,3600"))
    assert(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="latest+10s"}),"2,1,3600"))
    assert_nil(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="latest+10m,now"}),"2,1,3600"))
    assert(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="latest+10m"}),"0,0,0"))
    assert(string.find(m.latest("beer.ale;1h:30d"),"2,1,3600"))

    m.process("beer.ale.pale 7 4")
    -- the latest is not affected
    assert(string.find(m.latest("beer.ale;1h:30d"),"2,1,3600"))
    assert(string.find(m.graph("beer.ale.pale;1h:30d","latest-56m"),"7,1,0"))
    -- lets check the range
    local g = m.graph("beer.ale.pale;1h:30d","0..latest")
    assert(string.find(g,"2,1,3600"))
    assert(string.find(g,"7,1,0"))
    g = m.graph("beer.ale.pale;1h:30d","latest..0")

    assert(string.find(g,"[[2,1,3600],[7,1,0]]"))
    m.process("beer.ale.pale 9 64")
    g = m.graph("beer.ale.pale;1m:12h",{timestamp="latest..0"})
    assert(string.find(g,"[[2,1,3600],[9,1,60],[7,1,0]]"))

    m.process("beer.ale.brown 90 4400")
    assert(string.find(m.latest("beer.ale;1h:30d"),"92,2,3600"))
    -- we have two hits 3+7 at times 3 and 4 which are adjusted to 0

    m.process("beer.ale.brown 77 7201")
    assert_nil(string.find(m.graph("beer.ale;1h:30d",{timestamp="latest,latest-2h"}),"92,2,3600"))
    assert(string.find(m.graph("beer.ale;1h:30d","latest-3m"),"92,2,3600"))
  end

  for_each_db("./tests/temp/process",helper)
end

function test_update_only_relevant()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))

    m.process("beer.ale.pale 7 4")
    m.process("beer.ale.brown 6 54")
    assert(string.find(m.latest("beer.ale;1m:12h"),"13,2,0"))


    m.process("beer.ale.burton 32 91")

    assert(string.find(m.latest("beer.ale.pale;1m:12h"),"7,1,0",1,true))
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"[6,1,0]",1,true))
    assert(string.find(m.latest("beer.ale.burton;1m:12h"),"[32,1,60]",1,true))
    assert(string.find(m.latest("beer.ale;1m:12h"),"[32,1,60]",1,true))
    assert(string.find(m.slot("beer.ale.burton;1m:12h",{timestamp=93}),"[32,1,60]",1,true))

    m.process("beer.ale 132 121")
    assert(string.find(m.slot("beer.ale;1m:12h",{timestamp="121"}),"[132,1,120]",1,true))
    assert(string.find(m.latest("beer.ale;1m:12h"),"[132,1,120]",1,true))
    assert(string.find(m.latest("beer.ale.pale;1m:12h"),"[7,1,0]",1,true))
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"[6,1,0]",1,true))
    assert(string.find(m.latest("beer.ale.burton;1m:12h"),"[32,1,60]",1,true))

    m.process("beer.ale =94 121")
    assert(string.find(m.slot("beer.ale;1m:12h",{timestamp="121"}),"[94,1,120]",1,true))

    m.process("beer.ale.burton =164 854")
    assert(string.find(m.slot("beer.ale.burton;1m:12h",{timestamp="latest"}),"[164,1,840]",1,true))
  end

  for_each_db("./tests/temp/update_only_relevant",helper)
end


function test_metric_one_level_childs()
  local function helper(db)
    local m = mule(db)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))

    m.process("beer.ale.pale 7 4")
    m.process("beer.ale.pale.hello 7 4")
    m.process("beer.ale.pale.hello.cruel 7 4")
    m.process("beer.ale.brown 6 54")
    m.process("beer.ale.brown.world 6 54")
    m.process("beer.ale.burton 32 91")
    m.process("beer.ale 132 121")

    local tests = {
      {"beer.ale.brown;1h:30d",1},
      {"beer.ale;1m:12h",3},
      {"beer;1m:12h",1},
      {"beer",2},
      {"",0},
      {"foo",0},
    }

    for j,t in ipairs(tests) do
      local childs = {}

      for i in one_level_childs(db,t[1]) do
        table.insert(childs,i)
      end
      assert_equal(t[2],#childs,j)
    end
  end

  for_each_db("./tests/temp/one_level_childs",helper,true)
end


function test_dump_restore()
  local line = " beer.stout.irish;5m:2d  1 1 1320364800  1 1 1344729900  1 1 1320019800  1 1 1320538500  1 1 1324858800  1 1 1351988700  1 1 1320366600  1 1 1331426100  1 1 1323996000  1 1 1320194700  1 1 1326588600  1 1 1333328100  1 1 1320195600  1 1 1329008700  1 1 1317604200  1 1 1319850900  1 1 1320196800  1 1 1314321900  2 1 1320543000  1 1 1321925700  1 1 1317433200  1 1 1317951900  1 1 1303609800  1 1 1317779700  1 1 1320717900  1 1 1318299000  1 1 1324520100  1 1 1315707900  1 1 1318991400  2 1 1325558100  1 1 1310524800  1 1 1327459500  1 1 1317955800  1 1 1322276100  1 1 1319857200  1 1 1325905500  1 1 1320203400  1 1 1316402100  1 1 1317439200  1 1 1352345100  1 1 1317439800  1 1 1318304400  1 1 1317786300  1 1 1310183400  1 1 1319169300  1 1 1317614400  1 1 1318133100  1 1 1301371800  1 1 1317788100  1 1 1317788400  1 1 1317615900  1 1 1302409800  1 1 1320035700  1 1 1313642400  2 1 1318999500  1 1 1317963000  1 1 1318308900  1 1 1317272400  1 1 1318482300  1 1 1308287400  1 1 1318828500  1 1 1318828800  1 1 1317446700  2 1 1319866200  1 1 1320039300  1 1 1318830000  1 1 1317966300  1 1 1318485000  1 1 1335419700  1 1 1319522400  1 1 1317794700  1 1 1318486200  1 1 1325916900  1 1 1327645200  1 1 1319523900  1 1 1350973800  1 1 1318487700  1 1 1329201600  1 1 1342161900  1 1 1318661400  2 2 1326783300  1 1 1318834800  1 1 1334214300  1 1 1319699400  1 1 1336288500  1 1 1347693600  1 1 1319527500  1 1 1338708600  3 1 1334907300  14 1 1334043600  1 1 1318319100  1 1 1317801000  1 1 1335426900  1 1 1319702400  1 1 1334909100  1 1 1336983000  1 1 1333872900  1 1 1348215600  1 1 1319876700  1 1 1323678600  1 1 1321605300  1 1 1333356000  1 1 1350809100  1 1 1320569400  1 1 1321952100  2 1 1332147600  1 1 1336640700  1 1 1334394600  1 1 1320570900  1 1 1332321600  1 1 1326619500  1 1 1320226200  1 1 1341308100  1 1 1321782000  1 1 1331631900  1 1 1328521800  1 1 1325584500  1 1 1340964000  1 1 1333188300  1 1 1336990200  1 1 1335608100  1 1 1332843600  1 1 1331461500  1 1 1320921000  1 1 1333535700  1 1 1333363200  2 1 1336819500  1 1 1319021400  1 1 1331290500  1 1 1349089200  1 1 1350126300  2 1 1335611400  1 1 1351509300  1 1 1320924000  1 1 1325589900  1 1 1320233400  1 1 1332848100  1 1 1333366800  1 1 1328183100  1 1 1339588200  1 1 1328183700  1 1 1334923200  1 1 1338206700  1 1 1334923800  1 1 1334232900  6 1 1320063600  1 1 1331295900  1 1 1320582600  2 1 1327494900  1 1 1320756000  1 1 1330778700  1 1 1330433400  1 1 1328014500  1 1 1337346000  1 1 1332507900  1 1 1334063400  1 1 1339247700  1 1 1335446400  9 1 1320931500  1 1 1331645400  1 1 1324388100  1 1 1336311600  1 1 1348926300  1 1 1325598600  1 1 1326290100  1 1 1353074400  2 1 1342188300  1 1 1324735800  1 1 1344435300  1 1 1324390800  1 1 1349447100  1 1 1349274600  3 2 1350138900  1 1 1350139200  1 1 1319899500  1 1 1332168600  1 1 1351695300  1 1 1320937200  1 1 1329404700  2 1 1323184200  1 1 1321283700  1 1 1334762400  2 1 1332861900  2 1 1333553400  1 1 1331307300  1 1 1320939600  1 1 1342885500  1 1 1336146600  1 1 1334418900  1 1 1324396800  1 1 1327334700  1 1 1332864600  1 1 1320596100  1 1 1341505200  1 1 1329927900  1 1 1350318600  1 1 1351182900  1 1 1335112800  1 1 1349455500  1 1 1324054200  1 1 1332694500  1 1 1330966800  1 1 1329930300  1 1 1346519400  1 1 1328894100  1 1 1349803200  1 1 1342373100  1 1 1348421400  1 1 1338226500  1 1 1353087600  1 1 1329932700  1 1 1331142600  1 1 1341510900  1 1 1320775200  1 1 1321466700  1 1 1330452600  1 1 1326132900  1 1 1346350800  1 1 1352226300  1 1 1320777000  1 1 1330108500  1 1 1324579200  1 1 1320432300  2 1 1320087000  1 1 1346180100  1 1 1320260400  1 1 1349118300  1 1 1326309000  1 1 1320088500  1 1 1334258400  1 1 1322162700  1 1 1337023800  1 1 1350329700  1 1 1332013200  4 1 1344627900  2 1 1346701800  1 1 1344282900  1 1 1323892800  1 1 1346875500  1 1 1334088600  1 1 1326485700  1 1 1327695600  1 1 1322684700  1 1 1332016200  1 1 1348605300  1 1 1340656800  1 1 1350852300  2 2 1323031800  1 1 1332363300  1 1 1338066000  1 1 1347224700  1 1 1321305000  1 1 1340658900  1 1 1322860800  2 1 1328217900  1 1 1337376600  1 1 1330119300  2 1 1319233200  1 1 1325108700  1 1 1331848200  2 1 1332885300  1 1 1319925600  1 1 1333922700  1 1 1331331000  1 1 1346883300  1 1 1327702800  1 1 1324938300  1 1 1332887400  1 1 1331332500  1 1 1318027200  1 1 1352933100  1 1 1328050200  2 1 1332716100  1 1 1328050800  1 1 1322175900  1 1 1325805000  1 1 1328915700  2 1 1333927200  1 1 1329089100  1 1 1350689400  1 1 1319067300  1 1 1329954000  1 1 1323215100  1 1 1344642600  1 1 1337212500  1 1 1319587200  1 1 1323907500  1 1 1320797400  1 1 1320106500  2 1 1319415600  1 1 1318551900  1 1 1329784200  1 1 1317515700  1 1 1318034400  1 1 1322009100  1 1 1345510200  1 1 1317689700  1 1 1314061200  1 1 1320800700  2 1 1320109800  1 1 1318209300  1 1 1301102400  1 1 1318382700  1 1 1320111000  1 1 1319592900  1 1 1320284400  3 1 1319593500  1 1 1317865800  1 1 1319939700  1 1 1331344800  1 1 1317521100  1 1 1309054200  1 1 1293848100  1 1 1317349200  1 1 1317867900  1 1 1302316200  1 1 1317177300  1 1 1316313600  1 1 1338259500  1 1 1317351000  1 1 1317524100  1 1 1319425200  1 1 1319771100  1 1 1319253000  1 1 1304565300  2 1 1317180000  1 1 1309922700  1 1 1319254200  1 1 1318217700  1 1 1313206800  1 1 1319427900  1 1 1319428200  1 1 1316490900  2 1 1317700800  1 1 1317355500  1 1 1317874200  1 1 1315628100  1 1 1311135600  1 1 1317011100  1 1 1319257800  1 1 1311827700  1 1 1319949600  1 1 1318394700  1 1 1308027000  1 1 1320814500  1 1 1313384400  1 1 1317186300  1 1 1318914600  1 1 1319951700  2 1 1317360000  1 1 1320816300  1 1 1318915800  1 1 1320816900  1 1 1313905200  1 1 1324619100  1 1 1346565000  1 1 1318571700  1 1 1321855200  1 1 1320127500  2 1 1320819000  1 1 1317363300  1 1 1314253200  1 1 1318746300  1 1 1333953000  1 1 1323412500  1 1 1319956800  1 1 1333089900  1 1 1347605400  1 1 1320130500  1 1 1319439600  1 1 1319439900  1 1 1345187400  1 1 1320822900  1 1 1332746400  2 1 1334301900  1 1 1325662200  1 1 1333438500  1 1 1330674000  1 1 1321688700  1 1 1348818600  1 1 1336895700  1 1 1320307200  1 1 1345190700  1 1 1342080600  1 1 1320653700  1 1 1320654000  1 1 1348129500  1 1 1326184200  1 1 1333269300  1 1 1331541600  1 1 1323765900  2 1 1327740600  1 1 1348304100  1 1 1332579600  1 1 1349514300  1 1 1329815400  1 1 1339665300  1 1 1321521600  1 1 1320485100  1 1 1341739800  1 1 1336901700  1 1 1324633200  1 1 1346751900  1 1 1335520200  7 1 1323251700  1 1 1336384800  2 2 1331201100  5 1 1329127800  1 1 1329473700  1 1 1327573200  1 1 1348827900  1 1 1321871400  1 1 1337596500  1 1 1342780800  1 1 1327574700  1 1 1351594200  1 1 1350903300  1 1 1328958000  1 1 1328267100  1 1 1331896200  1 1 1333451700  1 1 1328613600  1 1 1348658700  2 1 1322047800  2 1 1323257700  1 1 1331206800  1 1 1328096700  1 1 1322567400  1 1 1332935700  1 1 1345723200  1 1 1329998700  1 1 1350389400  1 1 1338293700  1 1 1351599600  1 1 1331900700  1 1 1325680200  1 1 1332938100  1 1 1319978400  2 2 1322570700  2 1 1324126200  1 1 1328100900  1 1 1345035600  1 1 1348319100  1 1 1333113000  1 1 1345727700  1 1 1337606400  1 1 1324646700  1 1 1351431000  1 1 1317908100  1 1 1334670000  1 1 1331732700  1 1 1350741000  1 1 1334152500  1 1 1349532000  1 1 1347631500  1 1 1345385400  1 1 1326723300  1 1 1345213200  1 1 1320675900  1 1 1346596200  1 1 1348842900  1 1 1337438400  2 1 1321886700  1 1 1331391000  1 1 1322578500  1 1 1347634800  1 1 1333811100  1 1 1348326600  1 1 1335539700  1 1 1324308000  1 1 1320333900  1 1 1331911800  1 1 1331048100  2 1 1342626000  1 1 1330357500  1 1 1332258600  1 1 1329321300  1 1 1340380800  1 1 1325865900  1 1 1333469400  1 1 1320682500  1 1 1329841200  1 1 1351787100  1 1 1347985800  2 1 1320165300  1 1 1323794400  1 1 1324658700  3 1 1319993400  1 1 1325004900  1 1 1326387600  1 1 1328807100  1 1 1330362600  1 1 1330362900  1 1 1323278400  1 1 1327425900  1 1 1328808600  1 1 1340559300  1 1 1348854000  1 1 1322588700  1 1 1335203400  1 1 1331747700  1 1 1332093600  1 1 1322935500  1 1 1326046200  1 1 1326046500  2 1 1323454800  2 1 1327602300  1 1 1344191400  1 1 1335551700  1 1 1327776000  1 1 1349721900  1 1 1345056600  1 1 1323111300  1 1 1333479600  1 1 1349723100  1 1 1353179400  1 1 1350933300  1 1 1333653600  1 1 1320348300  1 1 1346095800  1 1 1351625700  1 1 1329334800  1 1 1351280700  1 1 1343505000  1 1 1350935700  1 1 1323979200  1 1 1332792300  1 1 1347135000  1 1 1327090500  1 1 1326745200  1 1 1331929500  2 1 1330547400  1 1 1334522100  1 1 1336768800  1 1 1327265100  1 1 1328475000  1 1 1331412900  1 1 1337461200  1 1 1328648700  1 1 1329340200  1 1 1339535700  9 2 1349385600  1 1 1327267500  1 1 1325367000  1 1 1346967300  1 1 1349386800  1 1 1320702300  1 1 1320702600  1 1 1321912500  1 1 1331762400  1 1 1331417100  2 1 1323814200  1 1 1330380900  1 1 1334874000  1 1 1337984700  1 1 1320359400  1 1 1336948500  2 1 1353019200  1 1 1350945900  1 1 1348527000  1 1 1331938500  1 1 1325199600  2 1 1329001500  1 1 1331939400  1 1 1322090100  1 1 1326237600  1 1 1321399500  1 1 1322782200  1 1 1320708900  1 1 1323992400  1 1 1325547900  1 1 1323301800  1 1 1329177300"

  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 5m:2d"}))
    -- the maximal time stamp is 1353179400 and there are exactly 4 slots which are no more
    -- than 48 hours ago
    m.process(line)
    assert(string.find(m.graph("beer.stout.irish;5m:2d"),'"data": {"beer.stout.irish;5m:2d": [[1,1,1353074400],[1,1,1353087600],[1,1,1353179400],[2,1,1353019200]]',1,true))
  end

  for_each_db("./tests/temp/dump_restore",helper)
end


function test_pale()
  local function helper(db)
    local m = mule(db)
    m.configure(table_itr({"beer. 5m:48h 1h:30d 1d:3y"}))

    m.process("./tests/fixtures/pale.dump")
    assert(string.find(m.slot("beer.ale.pale;1h:30d",{timestamp="1360800000"}),"274,244",1,true))
    assert(string.find(m.slot("beer.ale;5m:2d",{timestamp="1361127300"}),"1526,756",1,true))
    m.process("./tests/fixtures/pale.mule")
    assert(string.find(m.slot("beer.ale.pale;5m:2d",{timestamp="1361300362"}),"19,11",1,true))

    assert(string.find(m.slot("beer.ale.pale.rb;5m:2d",{timestamp="1361300428"}),"11,5",1,true))
    assert(string.find(m.slot("beer.ale;5m:2d",{timestamp="1361300362"}),"46,27",1,true))
  end

  for_each_db("./tests/temp/pale",helper,true)
end

function test_key()
  local function helper(db)
    local m = mule(db)
    m.configure(table_itr({"beer. 5m:48h 1h:30d 1d:3y"}))

    m.process("./tests/fixtures/pale.mule")
    assert(m.key("beer",{})==m.key("beer",{level=1}))

    -- there are 61 unique keys in pale.mule all are beer.pale sub keys
    -- (cut -d' ' -f 1 tests/fixtures/pale.mule  | sort | uniq | wc -l)
    local all_keys = string.match(m.key("beer",{deep=true}),"%[(.+)%]")
    assert_equal((61+2)*3,#split(all_keys,","))
    all_keys = string.match(m.key("beer",{level=4}),"%[(.+)%]")
    assert_equal((61+2)*3,#split(all_keys,","))

    all_keys = string.match(m.key("beer",{level=2}),"%[(.+)%]")
    assert_equal((2+2)*3,#split(all_keys,","))

  end

  helper(in_memory_db())
end

function test_bounded_by_level()
  assert(bounded_by_level("hello.cruel.world","hello",2))
  assert_false(bounded_by_level("hello.cruel.world","hello",1))
  assert(bounded_by_level("hello.cruel.world","hello.cruel",1))
  assert(bounded_by_level("hello.cruel.world","hello.cruel.world",1))
  assert(bounded_by_level("hello.cruel.world","hello.cruel",12))
end


function test_duplicate_timestamps()
  local db = column_db_factory("temp/duplicate_timestamps")
  local m = mule(db)
  m.configure(n_lines(109,io.lines("./tests/fixtures/d_conf")))
  m.process(n_lines(109,io.lines("./tests/fixtures/d_input.mule")))
  --print(m.dump("Johnston.Morfin",{to_str=true}).get_string())
  for l in string_lines(m.dump("Johnston.Morfin",{to_str=true}).get_string()) do
    if #l>0 then
      assert_equal(4,#split(l," "),l)
    end
  end
end

function test_dashes_in_keys()
  local db = column_db_factory("temp/dashes_in_keys")
  local m = mule(db)
  m.configure(n_lines(109,io.lines("./tests/fixtures/d_conf")))
  m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
  m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
  assert(string.find(m.key("Johnston",{deep=true}),"Sweet%-Nuthin"))
  assert(string.find(m.dump("Johnston.Emilia",{to_str=true}).get_string(),"Sweet%-Nuthin;1s:1m 78 1 300"))
  m.process("Johnston.Emilia.Sweet-Nuthin 2 300")
  assert(string.find(m.dump("Johnston.Emilia",{to_str=true}).get_string(),"Sweet%-Nuthin;1m:1h 80 2 300"))
  assert(string.find(m.graph("Johnston",{numchilds=true}),'{"Johnston": {"numchilds": 3}'))
  assert_nil(string.find(m.graph("Johnston",{numchilds=true}),'Johnston%.'))
end

--verbose_log(true)
--profiler.start("profiler.out")