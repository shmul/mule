require "mulelib"
require "tests.strict"
pcall(require, "profiler")
require "lunit"
require "memory_store"
local cdb = require "column_db"
local mdb = require "lightning_mdb"
local p = require "purepack"

module( "test_mulelib", lunit.testcase,package.seeall )

local function column_db_factory(name_)
  p.set_pack_lib("bits")
  local dir = create_test_directory(name_.."_cdb")
  return cdb.column_db(dir)
end


local function lightning_db_factory(name_)
  p.set_pack_lib("lpack")
  local dir = create_test_directory(name_.."_mdb")
  return mdb.lightning_mdb(dir)
end

local function memory_db_factory(name_)
  p.set_pack_lib("purepack")
  return in_memory_db()
end

local function for_each_db(name_,func_,no_mule_)
  local dbs = {
    memory_db_factory(),
    lightning_db_factory(name_),
    column_db_factory(name_)
  }

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

  seq.update(0,1,10)
  assert_equal(10,seq.slot(0)._sum)
  assert_equal(10,seq.slot(seq.latest())._sum)
  seq.update(1,1,17)
  assert_equal(27,seq.slot(0)._sum)
  assert_equal(2,seq.slot(0)._hits)
  assert_equal(27,seq.slot(seq.latest())._sum)
  seq.update(3660,1,3)
  assert_equal(3,seq.slot(1)._sum)
  assert_equal(3,seq.slot(seq.latest())._sum)
  seq.update(60,1,7) -- this is in the past and should be discarded
  assert_equal(3,seq.slot(1)._sum)
  assert_equal(1,seq.slot(1)._hits)
  assert_equal(3,seq.slot(seq.latest())._sum)
  seq.update(7260,1,89)
  assert_equal(89,seq.slot(1)._sum)
  assert_equal(1,seq.slot(1)._hits)
  assert_equal(89,seq.slot(seq.latest())._sum)

  --seq.serialize(stdout(", "))
  local tbl = {}
  seq.serialize({all_slots=true},insert_all_args(tbl),insert_all_args(tbl))
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
    seq.serialize({all_slots=true},insert_all_args(tbl1),insert_all_args(tbl1))
    for i,v in ipairs(tbl) do
      assert_equal(v,tbl1[i],i)
    end

    seq.update(10799,1,43)
    assert_equal(43,seq.slot(59)._sum)
    assert_equal(1,seq.slot(59)._hits)

    seq.update(10800,1,99)
    assert_equal(99,seq.slot(0)._sum)
    assert_equal(1,seq.slot(0)._hits)

    tbl = {}
    seq.serialize({sorted=true,all_slots=true},insert_all_args(tbl),insert_all_args(tbl))

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
    {"now-10000..now",1430216100,1430215500,{1430206100,1430216100}},
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
  for_each_db("test_sequences",helper_time_sequence,true)
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
  local function helper(m)
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
  for_each_db("test_factories",helper)
end

function test_modify_factories_1()
  local function helper(m)

    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.ale 60s:24h"}))

    assert_equal(3,#m.get_factories()["beer.ale"])

    m.modify_factories({{"beer.ale","1h:30d","2h:90d"}})
    assert_equal(3,#m.get_factories()["beer.ale"])
    local factories = m.get_factories()
    assert(factories["beer.ale"])
    -- first retention 60s:12h
    assert_equal(60,factories["beer.ale"][1][1])
    assert_equal(12*60*60,factories["beer.ale"][1][2])
    -- first retention 60s:24h
    assert_equal(60,factories["beer.ale"][2][1])
    assert_equal(24*60*60,factories["beer.ale"][2][2])

    -- 3rd retention is new 2h:90d
    assert_equal(2*60*60,factories["beer.ale"][3][1])
    assert_equal(90*24*60*60,factories["beer.ale"][3][2])
  end
  for_each_db("test_factories_1",helper)
end

local function sequence_any(seq_,callback_)
  local out = {}

  seq_.serialize({all_slots=true},insert_all_args(out),insert_all_args(out))
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

function test_export_configuration()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))

    assert(string.find(m.export_configuration(),'"beer.ale": ["1m:12h" ,"1h:30d" ]',1,true))
    assert(string.find(m.export_configuration(),'"beer.wheat": ["10m:1y" ]',1,true))
  end
  for_each_db("test_export_configuration",helper)
end

function test_factories_out()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))
    assert(string.find(m.export_configuration(),'"beer.ale": ["1m:12h" ,"1h:30d" ]',1,true))

    local fo = m.factories_out("beer.wheat")
    assert(string.find(fo,'"beer.wheat": ["10m:1y" ]',1,true))
    assert(string.find(m.export_configuration(),'"beer.wheat": ["10m:1y" ]',1,true))

    -- now really remove (with force)
    fo = m.factories_out("beer.wheat",{force=true})
    assert(string.find(fo,'"beer.wheat": ["10m:1y" ]',1,true))
    assert_nil(string.find(m.export_configuration(),'"beer.wheat": ["10m:1y" ]',1,true))

    -- just to verify that we don't crash on non-existing factories
    m.factories_out("wine")
  end
  for_each_db("test_factories_out",helper)
end

function test_process_in_memory()
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
  for_each_db("test_process_in_memory",helper)
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
    assert(string.find(m.latest("beer"),"70,3,74857800"))

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

  for_each_db("top_level",helper)
end

function test_modify_factories()
  local function helper(m)
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
  for_each_db("modify_factories",helper)
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

    assert(string.find(m.graph("beer.stout;1h:30d"),'[143,1,74858400]',1,true))
    assert(string.find(m.graph("beer.stout;1h:30d"),'[98,1,74854800]',1,true))
    m.process(".reset beer.stout timestamp=74857920&force=false")
    assert(string.find(m.graph("beer.stout;1h:30d"),'[143,1,74858400]',1,true))
    assert(string.find(m.graph("beer.stout;1h:30d"),'[0,0,74854800]',1,true))

    assert_nil(string.find(m.graph("beer.stout;1h:30d"),'[98,1,74858400]',1,true))
    assert(non_empty_metrics(m.matching_sequences("beer")))
    m.process(".reset beer.stout force=true&level=1")
    assert(non_empty_metrics(m.matching_sequences("beer")))

    assert(empty_metrics(m.matching_sequences("beer.stout")))
    assert(empty_metrics(m.matching_sequences("beer.ale.irish")))
    assert(non_empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))


    m.process(".reset beer.ale force=true&level=2")
    assert(non_empty_metrics(m.matching_sequences("beer")))
    assert(empty_metrics(m.matching_sequences("beer.ale")))
    assert(empty_metrics(m.matching_sequences("beer.ale.brown")))
    assert(empty_metrics(m.matching_sequences("beer.ale.brown.newcastle")))
  end


  for_each_db("reset",helper)
end

function test_reset2()
  local line = "beer.stout.irish;5m:3d 2 1 1418601600 16 5 1418601900 26 5 1418602200 8 3 1418602500 9 4 1418602800 11 4 1418603100 3 1 1418603400 29 5 1418603700 9 2 1418604000 9 7 1418604300 42 5 1418604600 25 7 1418604900 16 4 1418605200 6 3 1418605500 25 5 1418605800 15 7 1418606100 18 6 1418606400 6 4 1418606700 23 3 1418607000 13 5 1418607300 8 3 1418607600 41 7 1418607900 9 4 1418608200 9 4 1418608500 2 2 1418608800 5 2 1418609100 5 2 1418609400 3 2 1418609700 17 5 1418610000 7 4 1418610300 11 4 1418610600 6 3 1418610900 9 6 1418611200 5 2 1418611500 6 3 1418611800 2 2 1418612100 5 2 1418612400 3 2 1418612700 25 5 1418613000 10 3 1418613300 2 1 1418613600 26 9 1418613900 2 2 1418614200 5 3 1418614500 12 4 1418614800 7 5 1418615100 1 1 1418615400 6 3 1418615700 9 3 1418616000 3 1 1418616300 27 1 1418616600 6 4 1418616900 20 3 1418617200 1 1 1418617500 9 3 1418617800 6 5 1418618100 9 3 1418359200 1 1 1418618700 1 1 1418619000 9 3 1418619300 4 3 1418619600 14 3 1418619900 2 2 1418620200 10 5 1418620500 1 1 1418620800 2 2 1418621100 13 5 1418621400 12 3 1418621700 20 5 1418622000 6 3 1418622300 4 4 1418622600 22 6 1418622900 20 7 1418623200 7 3 1418623500 7 3 1418623800 1 1 1418624100 5 3 1418624400 6 2 1418624700 18 6 1418625000 31 8 1418625300 13 6 1418625600 35 10 1418625900 19 6 1418626200 46 8 1418626500 17 6 1418626800 18 4 1418627100 13 7 1418627400 11 6 1418627700 5 4 1418628000 19 11 1418628300 29 12 1418628600 45 11 1418628900 40 9 1418629200 13 8 1418629500 32 7 1418629800 29 11 1418630100 18 10 1418630400 29 10 1418630700 13 7 1418631000 40 7 1418631300 93 11 1418631600 80 15 1418631900 29 13 1418632200 45 14 1418632500 3 2 1418632800 49 18 1418633100 44 12 1418633400 54 9 1418633700 66 16 1418634000 62 19 1418634300 50 15 1418634600 71 25 1418634900 41 12 1418635200 92 20 1418635500 52 14 1418635800 35 10 1418636100 39 12 1418636400 42 11 1418636700 50 14 1418637000 40 17 1418637300 39 19 1418637600 24 10 1418637900 35 10 1418638200 30 12 1418638500 35 16 1418638800 39 9 1418639100 16 8 1418639400 20 9 1418639700 71 14 1418640000 17 7 1418640300 59 13 1418640600 41 10 1418640900 54 17 1418641200 28 10 1418641500 30 12 1418641800 36 13 1418642100 72 17 1418642400 39 14 1418642700 62 19 1418643000 106 20 1418643300 119 18 1418643600 153 28 1418643900 175 28 1418644200 147 23 1418644500 343 39 1418644800 165 32 1418645100 222 30 1418645400 215 28 1418645700 115 28 1418646000 157 26 1418646300 278 32 1418646600 274 32 1418646900 335 42 1418647200 319 34 1418647500 318 40 1418647800 794 52 1418648100 1078 44 1418648400 1827 50 1418648700 1748 60 1418649000 1823 51 1418649300 2042 55 1418649600 1489 51 1418649900 1595 58 1418650200 1732 57 1418650500 1631 53 1418650800 652 39 1418651100 594 28 1418651400 941 36 1418651700 1023 42 1418652000 549 34 1418652300 757 37 1418652600 477 41 1418652900 464 32 1418653200 731 64 1418653500 534 39 1418653800 663 51 1418654100 309 28 1418654400 319 28 1418654700 393 23 1418655000 424 43 1418655300 469 60 1418655600 948 65 1418655900 617 61 1418656200 788 66 1418656500 466 61 1418656800 818 74 1418657100 752 70 1418657400 879 83 1418657700 692 65 1418658000 395 55 1418658300 584 46 1418658600 447 53 1418658900 558 74 1418659200 443 63 1418659500 473 57 1418659800 497 69 1418660100 330 65 1418660400 309 66 1418660700 398 66 1418661000 381 65 1418661300 525 65 1418661600 135 38 1418661900 328 44 1418662200 225 48 1418662500 326 50 1418662800 349 44 1418663100 385 45 1418663400 107 35 1418663700 184 35 1418664000 178 35 1418664300 142 39 1418664600 136 25 1418664900 119 24 1418665200 96 31 1418665500 124 42 1418665800 110 32 1418666100 125 35 1418666400 202 38 1418666700 202 36 1418667000 118 29 1418667300 138 33 1418667600 120 25 1418667900 130 24 1418668200 190 36 1418668500 125 36 1418668800 170 35 1418669100 142 46 1418669400 156 38 1418669700 173 46 1418670000 128 37 1418670300 148 34 1418670600 137 31 1418670900 161 32 1418671200 226 39 1418671500 146 29 1418671800 125 37 1418672100 149 34 1418672400 212 32 1418672700 127 35 1418673000 167 43 1418673300 97 22 1418673600 88 30 1418673900 92 37 1418674200 117 32 1418674500 131 21 1418674800 168 35 1418675100 113 29 1418675400 139 26 1418675700 70 26 1418676000 105 26 1418676300 109 29 1418676600 111 29 1418676900 114 28 1418677200 140 25 1418677500 105 21 1418677800 84 21 1418678100 140 33 1418678400 108 25 1418678700 61 17 1418679000 87 18 1418679300 128 22 1418679600 88 21 1418679900 45 19 1418680200 75 19 1418680500 37 22 1418680800 51 23 1418681100 98 17 1418681400 37 13 1418681700 64 16 1418682000 41 17 1418682300 21 13 1418682600 41 17 1418682900 57 12 1418683200 48 14 1418683500 17 11 1418683800 20 5 1418684100 29 14 1418684400 10 9 1418684700 28 14 1418685000 10 6 1418685300 41 13 1418685600 32 10 1418685900 36 6 1418686200 14 8 1418686500 21 3 1418686800 5 5 1418687100 28 8 1418687400 19 7 1418687700 7 3 1418688000 20 4 1418688300 13 7 1418688600 14 6 1418688900 6 5 1418689200 5 3 1418689500 11 5 1418689800 28 10 1418690100 9 4 1418690400 15 9 1418690700 24 6 1418691000 26 7 1418691300 20 9 1418691600 6 4 1418691900 6 5 1418692200 6 4 1418692500 13 3 1418692800 32 7 1418693100 12 7 1418693400 10 5 1418693700 7 5 1418694000 3 3 1418694300 13 6 1418694600 9 5 1418694900 7 2 1418695200 9 2 1418695500 11 4 1418695800 10 6 1418696100 14 8 1418696400 16 4 1418696700 5 4 1418697000 5 4 1418697300 6 3 1418697600 18 4 1418697900 4 1 1418698200 5 2 1418698500 4 4 1418698800 6 2 1418699100 5 3 1418699400 10 4 1418699700 13 4 1418700000 7 3 1418700300 16 2 1418700600 11 2 1418700900 3 2 1418701200 11 2 1418442300 21 6 1418701800 22 3 1418183700 3 3 1418702400 35 6 1418702700 1 1 1418703000 7 2 1418444100 3 1 1418703600 2 2 1418703900 1 1 1418704200 2 1 1418704500 4 2 1418704800 6 2 1418705100 2 1 1418705400 7 5 1418705700 40 6 1418706000 1 1 1418706300 5 4 1418706600 4 2 1418706900 26 6 1418707200 17 6 1418707500 17 6 1418707800 16 7 1418708100 1 1 1418708400 22 6 1418708700 14 4 1418709000 22 4 1418709300 1 1 1418709600 2 2 1418709900 3 1 1418710200 9 3 1418710500 2 1 1418710800 21 11 1418711100 17 5 1418711400 5 4 1418711700 8 3 1418712000 7 6 1418712300 10 6 1418712600 27 5 1418712900 24 10 1418713200 34 8 1418713500 12 8 1418713800 26 5 1418714100 13 7 1418714400 16 9 1418714700 16 4 1418715000 26 8 1418715300 79 11 1418715600 10 8 1418715900 13 5 1418716200 45 12 1418716500 43 13 1418716800 22 8 1418717100 34 11 1418717400 37 11 1418717700 27 11 1418718000 51 19 1418718300 23 5 1418718600 41 15 1418718900 42 11 1418719200 44 14 1418719500 41 13 1418719800 81 13 1418720100 66 17 1418720400 60 18 1418720700 64 14 1418721000 62 17 1418721300 33 13 1418721600 42 12 1418721900 53 8 1418722200 3 1 1418463300 10 2 1418463600 2 1 1418463900 9 2 1418464200 70 26 1418205300 1 1 1418464800 2 1 1418465100 6 2 1418465400 1 1 1418465700 1 1 1418466000 10 2 1418466300 21 4 1418466600 4 1 1418466900 69 14 1418208000 1 1 1418467500 4 1 1418467800 5 5 1418468100 10 3 1418468400 18 5 1418468700 32 4 1418469000 8 2 1418469300 25 3 1418469600 28 4 1418469900 3 2 1418470200 3 2 1418470500 32 3 1418470800 4 2 1418471100 3 2 1418471400 23 2 1418471700 140 13 1418472000 62 6 1418472300 29 4 1418472600 90 6 1418472900 27 2 1418473200 7 3 1418473500 36 7 1418473800 36 7 1418474100 19 6 1418474400 44 9 1418474700 90 9 1418475000 127 10 1418475300 327 18 1418475600 327 8 1418475900 127 7 1418476200 136 14 1418476500 158 13 1418476800 165 7 1418477100 544 17 1418477400 1656 18 1418477700 1623 17 1418478000 2553 27 1418478300 2290 26 1418478600 2082 26 1418478900 1115 15 1418479200 813 17 1418479500 355 19 1418479800 178 12 1418480100 127 17 1418480400 167 13 1418480700 134 11 1418481000 180 14 1418481300 64 20 1418481600 76 13 1418481900 98 15 1418482200 106 10 1418482500 147 14 1418482800 78 9 1418483100 102 15 1418483400 60 13 1418483700 64 11 1418484000 59 11 1418484300 133 15 1418484600 105 16 1418484900 142 20 1418485200 133 12 1418485500 91 12 1418485800 72 15 1418486100 35 12 1418486400 108 15 1418486700 20 8 1418487000 51 10 1418487300 76 9 1418487600 59 15 1418487900 33 8 1418488200 84 13 1418488500 61 13 1418488800 23 7 1418489100 38 12 1418489400 26 12 1418489700 96 13 1418490000 33 13 1418490300 21 11 1418490600 89 10 1418490900 57 8 1418491200 35 10 1418491500 106 13 1418491800 48 13 1418492100 29 11 1418492400 35 15 1418492700 26 9 1418493000 44 9 1418493300 48 13 1418493600 98 10 1418493900 14 8 1418494200 26 6 1418494500 83 8 1418494800 48 10 1418495100 42 8 1418495400 43 9 1418495700 53 8 1418496000 82 8 1418496300 14 9 1418496600 46 7 1418496900 21 10 1418497200 6 5 1418497500 21 7 1418497800 9 6 1418498100 26 3 1418498400 16 5 1418498700 35 8 1418499000 20 4 1418499300 15 3 1418499600 11 3 1418499900 5 3 1418500200 68 10 1418500500 150 34 1418241600 42 5 1418501100 15 4 1418501400 24 3 1418501700 90 29 1418242800 36 3 1418502300 13 2 1418502600 5 4 1418502900 5 3 1418503200 177 26 1418244300 4 3 1418503800 3 3 1418504100 3 3 1418504400 13 2 1418504700 112 19 1418245800 1 1 1418505300 1 1 1418505600 6 3 1418505900 28 3 1418506200 21 1 1418506500 81 24 1418247600 1 1 1418507100 4 2 1418507400 3 1 1418507700 2 1 1418508000 5 4 1418508300 12 2 1418508600 3 1 1418508900 5 2 1418509200 2 1 1418509500 17 5 1418509800 7 6 1418510100 3 3 1418510400 2 1 1418510700 30 13 1418251800 1 1 1418511300 1 1 1418511600 1 1 1418511900 6 4 1418512200 2 2 1418512500 5 3 1418512800 2 1 1418513100 14 8 1418513400 17 7 1418513700 43 4 1418514000 25 8 1418255100 2 1 1418514600 35 5 1418514900 7 3 1418515200 3 2 1418515500 3 3 1418515800 2 2 1418516100 3 1 1418516400 3 1 1418516700 6 2 1418257800 29 2 1418517300 5 5 1418258400 13 3 1418258700 5 3 1418518200 9 5 1418259300 1 1 1418518800 11 5 1418259900 1 1 1418519400 3 3 1418519700 10 5 1418520000 11 4 1418520300 6 1 1418520600 1 1 1418520900 1 1 1418521200 1 1 1418521500 7 3 1418262600 1 1 1418522100 2 2 1418522400 4 3 1418522700 4 2 1418263800 11 3 1418264100 49 2 1418523600 62 5 1418523900 20 4 1418524200 38 3 1418524500 5 3 1418524800 8 6 1418525100 4 2 1418266200 3 2 1418266500 3 1 1418526000 2 2 1418526300 9 4 1418267400 13 4 1418267700 6 2 1418268000 21 6 1418009100 4 2 1418268600 4 2 1418268900 1 1 1418528400 1 1 1418528700 2 2 1418529000 10 7 1418270100 18 5 1418270400 19 2 1418529900 2 1 1418530200 1 1 1418271300 1 1 1418530800 11 2 1418531100 1 1 1418531400 11 4 1417494900 9 3 1418272800 5 1 1418532300 1 1 1418532600 1 1 1418532900 3 2 1418533200 1 1 1418533500 17 1 1418533800 3 2 1418534100 2 2 1418534400 10 4 1418534700 8 2 1418535000 15 5 1418276100 8 4 1418276400 2 1 1418276700 3 2 1418536200 7 3 1418536500 1 1 1418536800 2 1 1418537100 12 4 1418278200 2 1 1418537700 4 1 1418538000 7 4 1418538300 15 4 1418279400 1 1 1418538900 1 1 1418539200 2 2 1418539500 1 1 1418539800 2 1 1418540100 5 3 1418540400 19 4 1418281500 2 1 1418541000 2 1 1418541300 17 4 1418541600 7 3 1418541900 7 3 1418542200 19 3 1418542500 10 3 1418542800 16 3 1418543100 10 5 1418543400 6 4 1418543700 1 1 1418544000 15 4 1418544300 14 7 1418544600 11 5 1418544900 6 3 1418545200 11 5 1418545500 24 4 1418545800 27 6 1418546100 23 5 1418546400 12 5 1418546700 23 7 1418547000 10 5 1418547300 26 7 1418547600 37 7 1418547900 19 7 1418548200 11 4 1418548500 6 4 1418548800 3 2 1418549100 8 5 1418549400 16 4 1418549700 2 1 1418550000 4 2 1418550300 12 6 1418550600 25 6 1418550900 6 2 1418551200 8 3 1418551500 7 3 1418551800 5 4 1418552100 6 5 1418552400 7 2 1418552700 8 3 1418553000 14 6 1418553300 4 3 1418553600 7 2 1418553900 26 5 1418554200 4 3 1418554500 13 7 1418554800 7 5 1418555100 23 11 1418555400 17 6 1418555700 11 6 1418556000 6 5 1418556300 21 11 1418556600 9 5 1418556900 7 4 1418557200 6 5 1418557500 104 13 1418557800 7 4 1418558100 45 8 1418558400 12 3 1418558700 12 2 1418559000 61 6 1418559300 11 4 1418559600 4 2 1418559900 17 6 1418560200 14 5 1418560500 31 9 1418560800 50 6 1418561100 23 6 1418561400 46 6 1418561700 80 8 1418562000 50 6 1418562300 28 11 1418562600 63 9 1418562900 17 9 1418563200 33 10 1418563500 71 13 1418563800 27 7 1418564100 28 11 1418564400 54 6 1418564700 18 5 1418565000 30 7 1418565300 35 5 1418565600 112 10 1418565900 52 6 1418566200 9 4 1418566500 40 14 1418566800 34 10 1418567100 67 7 1418567400 20 7 1418567700 5 3 1418568000 12 5 1418568300 39 6 1418568600 17 3 1418568900 18 4 1418569200 13 7 1418569500 3 1 1418569800 15 7 1418570100 12 6 1418570400 13 4 1418570700 35 9 1418571000 11 6 1418571300 22 7 1418571600 10 4 1418571900 5 2 1418572200 43 9 1418572500 28 8 1418572800 36 6 1418573100 48 8 1418573400 22 5 1418573700 17 6 1418574000 209 41 1418315100 16 5 1418574600 15 5 1418574900 16 7 1418575200 16 4 1418575500 20 8 1418575800 22 2 1418576100 23 4 1418576400 11 3 1418576700 26 7 1418577000 8 6 1418577300 5 4 1418577600 2 2 1418577900 5 3 1418578200 3 3 1418578500 1 1 1418578800 14 3 1418579100 25 2 1418579400 1 1 1418579700 25 6 1418580000 38 7 1418580300 49 5 1418580600 21 1 1418580900 132 28 1418322000 176 27 1418322300 40 4 1418581800 46 6 1418582100 7 2 1418582400 29 5 1418582700 6 3 1418583000 23 5 1418583300 31 7 1418583600 4 3 1418583900 8 3 1418584200 14 3 1418584500 6 5 1418584800 35 5 1418585100 71 8 1418585400 17 4 1418585700 25 4 1418586000 6 5 1418586300 3 1 1418586600 8 4 1418586900 28 5 1418587200 6 2 1418587500 2 2 1418587800 14 4 1418588100 30 4 1418588400 24 6 1418588700 46 6 1418589000 34 5 1418589300 16 2 1418589600 14 2 1418589900 4 3 1418590200 11 2 1418590500 13 2 1418590800 58 4 1418591100 2 2 1418591400 8 4 1418591700 3 1 1418592000 3 3 1418592300 18 4 1418592600 6 3 1418592900 13 3 1418593200 76 22 1418334300 2 2 1418593800 4 2 1418594100 12 5 1418594400 1 1 1418594700 4 2 1418595000 4 3 1418595300 6 3 1418595600 101 8 1418595900 18 6 1418596200 8 4 1418596500 13 5 1418596800 8 4 1418597100 10 5 1418597400 3 2 1418597700 4 3 1418598000 12 2 1418598300 5 3 1418339400 1 1 1418598900 5 2 1418599200 13 6 1418599500 7 3 1418599800 2 1 1418600100 6 3 1418600400 9 5 1418600700 11 4 1418601000 11 4 1418601300"

  function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 5m:3d"}))
    m.process(line)
    assert(string.find(m.graph("beer.stout.irish;5m:3d"),'[8,3,1418602500]',1,true))
    assert(string.find(m.graph("beer.stout.irish;5m:3d"),'[9,4,1418602800]',1,true))
    m.process(".reset beer.stout.irish timestamp=1418602700&force=false&level=1")
    assert(string.find(m.graph("beer.stout.irish;5m:3d"),'[0,0,1418602500]',1,true))
    assert(string.find(m.graph("beer.stout.irish;5m:3d"),'[9,4,1418602800]',1,true))

  end

  for_each_db("reset2",helper)
end

function test_save_load()
  local function helper(db)
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
  for_each_db("save_load",helper,true)
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
  for_each_db("process_tokyo",helper)
end

function test_latest()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 3m:1h","beer.wheat 10m:1y"}))

    m.process("beer.ale.brown 3 3")
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"3,1,0"))
    assert(string.find(m.graph("beer.ale.brown;1m:12h",{timestamp="latest"}),"3,1,0"))
    assert(string.find(m.slot("beer.ale.brown;1m:12h",{timestamp="1"}),"3,1,0"))
    assert(string.find(m.latest("beer.ale.pale;1m:12h"),'"data": {}'))
    assert(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="latest"}),'"data": {}',1,true))
    assert(string.find(m.latest("beer.ale.pale;1h:30d"),'"data": {}'))


    -- the timestamp is adjusted
    assert(string.find(m.latest("beer.ale.brown"),"3,1,0"))
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"3,1,0"))


    m.process("beer.ale.pale 2 3601")
    assert(string.find(m.latest("beer.ale.brown;1m:12h"),"3,1,0"))
    assert(string.find(m.graph("beer.ale.brown;1m:12h",{timestamp="latest-90"}),'"beer.ale.brown;1m:12h": []',1,true))
    assert(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="3604"}),"2,1,3600"))
    assert(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="latest+10s"}),"2,1,3600"))
    assert_nil(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="latest+10m,now"}),"2,1,3600"))
    assert(string.find(m.graph("beer.ale.pale;1m:12h",{timestamp="latest+10m"}),'"beer.ale.pale;1m:12h": []',1,true))
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
    assert(string.find(g,"[[2,1,3600],[9,1,60],[7,1,0]]",1,true))

    m.process("beer.ale.brown 90 4400")
    assert(string.find(m.latest("beer.ale;1h:30d"),"92,2,3600"))
    -- we have two hits 3+7 at times 3 and 4 which are adjusted to 0

    m.process("beer.ale.brown 77 7201")
    assert_nil(string.find(m.graph("beer.ale;1h:30d",{timestamp="latest,latest-2h"}),"92,2,3600"))
    assert(string.find(m.graph("beer.ale;1h:30d","latest-3m"),"92,2,3600"))
  end

  for_each_db("process",helper)
end

function test_update_only_relevant()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h","beer.stout 3m:1h","beer.wheat 10m:1y"}))

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

    m.process("beer.ale.burton ^90 854")
    assert(string.find(m.slot("beer.ale.burton;1m:12h",{timestamp="latest"}),"[164,1,840]",1,true))

    m.process("beer.ale.burton ^190 854")
    assert(string.find(m.slot("beer.ale.burton;1m:12h",{timestamp="latest"}),"[190,1,840]",1,true))

  end

  for_each_db("update_only_relevant",helper)
end


function test_metric_one_level_children()
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
      {"beer.ale.brown",4},
      {"beer.ale",8},
      {"beer",2},
      {"",2},
      {"foo",0},
    }

    for j,t in ipairs(tests) do
      local children = 0
      for i in db.matching_keys(t[1],1) do
        if string.find(i,"metadata=",1,true)~=1 then
          children = children + 1
        end
      end
      assert_equal(t[2],children,j)
    end
  end

  for_each_db("one_level_children",helper,true)
end


function test_dump_restore()
  local line = " beer.stout.irish;5m:2d  1 1 1320364800  1 1 1344729900  1 1 1320019800  1 1 1320538500  1 1 1324858800  1 1 1351988700  1 1 1320366600  1 1 1331426100  1 1 1323996000  1 1 1320194700  1 1 1326588600  1 1 1333328100  1 1 1320195600  1 1 1329008700  1 1 1317604200  1 1 1319850900  1 1 1320196800  1 1 1314321900  2 1 1320543000  1 1 1321925700  1 1 1317433200  1 1 1317951900  1 1 1303609800  1 1 1317779700  1 1 1320717900  1 1 1318299000  1 1 1324520100  1 1 1315707900  1 1 1318991400  2 1 1325558100  1 1 1310524800  1 1 1327459500  1 1 1317955800  1 1 1322276100  1 1 1319857200  1 1 1325905500  1 1 1320203400  1 1 1316402100  1 1 1317439200  1 1 1352345100  1 1 1317439800  1 1 1318304400  1 1 1317786300  1 1 1310183400  1 1 1319169300  1 1 1317614400  1 1 1318133100  1 1 1301371800  1 1 1317788100  1 1 1317788400  1 1 1317615900  1 1 1302409800  1 1 1320035700  1 1 1313642400  2 1 1318999500  1 1 1317963000  1 1 1318308900  1 1 1317272400  1 1 1318482300  1 1 1308287400  1 1 1318828500  1 1 1318828800  1 1 1317446700  2 1 1319866200  1 1 1320039300  1 1 1318830000  1 1 1317966300  1 1 1318485000  1 1 1335419700  1 1 1319522400  1 1 1317794700  1 1 1318486200  1 1 1325916900  1 1 1327645200  1 1 1319523900  1 1 1350973800  1 1 1318487700  1 1 1329201600  1 1 1342161900  1 1 1318661400  2 2 1326783300  1 1 1318834800  1 1 1334214300  1 1 1319699400  1 1 1336288500  1 1 1347693600  1 1 1319527500  1 1 1338708600  3 1 1334907300  14 1 1334043600  1 1 1318319100  1 1 1317801000  1 1 1335426900  1 1 1319702400  1 1 1334909100  1 1 1336983000  1 1 1333872900  1 1 1348215600  1 1 1319876700  1 1 1323678600  1 1 1321605300  1 1 1333356000  1 1 1350809100  1 1 1320569400  1 1 1321952100  2 1 1332147600  1 1 1336640700  1 1 1334394600  1 1 1320570900  1 1 1332321600  1 1 1326619500  1 1 1320226200  1 1 1341308100  1 1 1321782000  1 1 1331631900  1 1 1328521800  1 1 1325584500  1 1 1340964000  1 1 1333188300  1 1 1336990200  1 1 1335608100  1 1 1332843600  1 1 1331461500  1 1 1320921000  1 1 1333535700  1 1 1333363200  2 1 1336819500  1 1 1319021400  1 1 1331290500  1 1 1349089200  1 1 1350126300  2 1 1335611400  1 1 1351509300  1 1 1320924000  1 1 1325589900  1 1 1320233400  1 1 1332848100  1 1 1333366800  1 1 1328183100  1 1 1339588200  1 1 1328183700  1 1 1334923200  1 1 1338206700  1 1 1334923800  1 1 1334232900  6 1 1320063600  1 1 1331295900  1 1 1320582600  2 1 1327494900  1 1 1320756000  1 1 1330778700  1 1 1330433400  1 1 1328014500  1 1 1337346000  1 1 1332507900  1 1 1334063400  1 1 1339247700  1 1 1335446400  9 1 1320931500  1 1 1331645400  1 1 1324388100  1 1 1336311600  1 1 1348926300  1 1 1325598600  1 1 1326290100  1 1 1353074400  2 1 1342188300  1 1 1324735800  1 1 1344435300  1 1 1324390800  1 1 1349447100  1 1 1349274600  3 2 1350138900  1 1 1350139200  1 1 1319899500  1 1 1332168600  1 1 1351695300  1 1 1320937200  1 1 1329404700  2 1 1323184200  1 1 1321283700  1 1 1334762400  2 1 1332861900  2 1 1333553400  1 1 1331307300  1 1 1320939600  1 1 1342885500  1 1 1336146600  1 1 1334418900  1 1 1324396800  1 1 1327334700  1 1 1332864600  1 1 1320596100  1 1 1341505200  1 1 1329927900  1 1 1350318600  1 1 1351182900  1 1 1335112800  1 1 1349455500  1 1 1324054200  1 1 1332694500  1 1 1330966800  1 1 1329930300  1 1 1346519400  1 1 1328894100  1 1 1349803200  1 1 1342373100  1 1 1348421400  1 1 1338226500  1 1 1353087600  1 1 1329932700  1 1 1331142600  1 1 1341510900  1 1 1320775200  1 1 1321466700  1 1 1330452600  1 1 1326132900  1 1 1346350800  1 1 1352226300  1 1 1320777000  1 1 1330108500  1 1 1324579200  1 1 1320432300  2 1 1320087000  1 1 1346180100  1 1 1320260400  1 1 1349118300  1 1 1326309000  1 1 1320088500  1 1 1334258400  1 1 1322162700  1 1 1337023800  1 1 1350329700  1 1 1332013200  4 1 1344627900  2 1 1346701800  1 1 1344282900  1 1 1323892800  1 1 1346875500  1 1 1334088600  1 1 1326485700  1 1 1327695600  1 1 1322684700  1 1 1332016200  1 1 1348605300  1 1 1340656800  1 1 1350852300  2 2 1323031800  1 1 1332363300  1 1 1338066000  1 1 1347224700  1 1 1321305000  1 1 1340658900  1 1 1322860800  2 1 1328217900  1 1 1337376600  1 1 1330119300  2 1 1319233200  1 1 1325108700  1 1 1331848200  2 1 1332885300  1 1 1319925600  1 1 1333922700  1 1 1331331000  1 1 1346883300  1 1 1327702800  1 1 1324938300  1 1 1332887400  1 1 1331332500  1 1 1318027200  1 1 1352933100  1 1 1328050200  2 1 1332716100  1 1 1328050800  1 1 1322175900  1 1 1325805000  1 1 1328915700  2 1 1333927200  1 1 1329089100  1 1 1350689400  1 1 1319067300  1 1 1329954000  1 1 1323215100  1 1 1344642600  1 1 1337212500  1 1 1319587200  1 1 1323907500  1 1 1320797400  1 1 1320106500  2 1 1319415600  1 1 1318551900  1 1 1329784200  1 1 1317515700  1 1 1318034400  1 1 1322009100  1 1 1345510200  1 1 1317689700  1 1 1314061200  1 1 1320800700  2 1 1320109800  1 1 1318209300  1 1 1301102400  1 1 1318382700  1 1 1320111000  1 1 1319592900  1 1 1320284400  3 1 1319593500  1 1 1317865800  1 1 1319939700  1 1 1331344800  1 1 1317521100  1 1 1309054200  1 1 1293848100  1 1 1317349200  1 1 1317867900  1 1 1302316200  1 1 1317177300  1 1 1316313600  1 1 1338259500  1 1 1317351000  1 1 1317524100  1 1 1319425200  1 1 1319771100  1 1 1319253000  1 1 1304565300  2 1 1317180000  1 1 1309922700  1 1 1319254200  1 1 1318217700  1 1 1313206800  1 1 1319427900  1 1 1319428200  1 1 1316490900  2 1 1317700800  1 1 1317355500  1 1 1317874200  1 1 1315628100  1 1 1311135600  1 1 1317011100  1 1 1319257800  1 1 1311827700  1 1 1319949600  1 1 1318394700  1 1 1308027000  1 1 1320814500  1 1 1313384400  1 1 1317186300  1 1 1318914600  1 1 1319951700  2 1 1317360000  1 1 1320816300  1 1 1318915800  1 1 1320816900  1 1 1313905200  1 1 1324619100  1 1 1346565000  1 1 1318571700  1 1 1321855200  1 1 1320127500  2 1 1320819000  1 1 1317363300  1 1 1314253200  1 1 1318746300  1 1 1333953000  1 1 1323412500  1 1 1319956800  1 1 1333089900  1 1 1347605400  1 1 1320130500  1 1 1319439600  1 1 1319439900  1 1 1345187400  1 1 1320822900  1 1 1332746400  2 1 1334301900  1 1 1325662200  1 1 1333438500  1 1 1330674000  1 1 1321688700  1 1 1348818600  1 1 1336895700  1 1 1320307200  1 1 1345190700  1 1 1342080600  1 1 1320653700  1 1 1320654000  1 1 1348129500  1 1 1326184200  1 1 1333269300  1 1 1331541600  1 1 1323765900  2 1 1327740600  1 1 1348304100  1 1 1332579600  1 1 1349514300  1 1 1329815400  1 1 1339665300  1 1 1321521600  1 1 1320485100  1 1 1341739800  1 1 1336901700  1 1 1324633200  1 1 1346751900  1 1 1335520200  7 1 1323251700  1 1 1336384800  2 2 1331201100  5 1 1329127800  1 1 1329473700  1 1 1327573200  1 1 1348827900  1 1 1321871400  1 1 1337596500  1 1 1342780800  1 1 1327574700  1 1 1351594200  1 1 1350903300  1 1 1328958000  1 1 1328267100  1 1 1331896200  1 1 1333451700  1 1 1328613600  1 1 1348658700  2 1 1322047800  2 1 1323257700  1 1 1331206800  1 1 1328096700  1 1 1322567400  1 1 1332935700  1 1 1345723200  1 1 1329998700  1 1 1350389400  1 1 1338293700  1 1 1351599600  1 1 1331900700  1 1 1325680200  1 1 1332938100  1 1 1319978400  2 2 1322570700  2 1 1324126200  1 1 1328100900  1 1 1345035600  1 1 1348319100  1 1 1333113000  1 1 1345727700  1 1 1337606400  1 1 1324646700  1 1 1351431000  1 1 1317908100  1 1 1334670000  1 1 1331732700  1 1 1350741000  1 1 1334152500  1 1 1349532000  1 1 1347631500  1 1 1345385400  1 1 1326723300  1 1 1345213200  1 1 1320675900  1 1 1346596200  1 1 1348842900  1 1 1337438400  2 1 1321886700  1 1 1331391000  1 1 1322578500  1 1 1347634800  1 1 1333811100  1 1 1348326600  1 1 1335539700  1 1 1324308000  1 1 1320333900  1 1 1331911800  1 1 1331048100  2 1 1342626000  1 1 1330357500  1 1 1332258600  1 1 1329321300  1 1 1340380800  1 1 1325865900  1 1 1333469400  1 1 1320682500  1 1 1329841200  1 1 1351787100  1 1 1347985800  2 1 1320165300  1 1 1323794400  1 1 1324658700  3 1 1319993400  1 1 1325004900  1 1 1326387600  1 1 1328807100  1 1 1330362600  1 1 1330362900  1 1 1323278400  1 1 1327425900  1 1 1328808600  1 1 1340559300  1 1 1348854000  1 1 1322588700  1 1 1335203400  1 1 1331747700  1 1 1332093600  1 1 1322935500  1 1 1326046200  1 1 1326046500  2 1 1323454800  2 1 1327602300  1 1 1344191400  1 1 1335551700  1 1 1327776000  1 1 1349721900  1 1 1345056600  1 1 1323111300  1 1 1333479600  1 1 1349723100  1 1 1353179400  1 1 1350933300  1 1 1333653600  1 1 1320348300  1 1 1346095800  1 1 1351625700  1 1 1329334800  1 1 1351280700  1 1 1343505000  1 1 1350935700  1 1 1323979200  1 1 1332792300  1 1 1347135000  1 1 1327090500  1 1 1326745200  1 1 1331929500  2 1 1330547400  1 1 1334522100  1 1 1336768800  1 1 1327265100  1 1 1328475000  1 1 1331412900  1 1 1337461200  1 1 1328648700  1 1 1329340200  1 1 1339535700  9 2 1349385600  1 1 1327267500  1 1 1325367000  1 1 1346967300  1 1 1349386800  1 1 1320702300  1 1 1320702600  1 1 1321912500  1 1 1331762400  1 1 1331417100  2 1 1323814200  1 1 1330380900  1 1 1334874000  1 1 1337984700  1 1 1320359400  1 1 1336948500  2 1 1353019200  1 1 1350945900  1 1 1348527000  1 1 1331938500  1 1 1325199600  2 1 1329001500  1 1 1331939400  1 1 1322090100  1 1 1326237600  1 1 1321399500  1 1 1322782200  1 1 1320708900  1 1 1323992400  1 1 1325547900  1 1 1323301800  1 1 1329177300"

  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.stout 5m:2d"}))
    -- the maximal time stamp is 1353179400 and there are exactly 4 slots which are no more
    -- than 48 hours ago
    m.process(line)
    assert(string.find(m.graph("beer.stout.irish;5m:2d",{timestamp="latest-2d+1..latest",filter="latest"}),'"data": {"beer.stout.irish;5m:2d": [[1,1,1353179400],[2,1,1353019200],[1,1,1353074400],[1,1,1353087600]]',1,true))
    assert(string.find(m.graph("beer.stout.irish;5m:2d",{timestamp="latest-2d+1..latest",filter="now"}),'"data": {"beer.stout.irish;5m:2d": []',1,true))
    assert(string.find(m.graph("beer.stout.irish;5m:2d",{filter="latest"}),'"data": {"beer.stout.irish;5m:2d": [[1,1,1353074400],[1,1,1353087600],[1,1,1353179400],[2,1,1353019200]]',1,true))

  end

  for_each_db("dump_restore",helper)
end


function test_pale()
  local function helper(db)
    local m = mule(db)
    m.configure(table_itr({"beer. 5m:48h 1h:30d 1d:3y"}))

    m.process("./tests/fixtures/pale.dump")

    assert(string.find(m.slot("beer.ale.pale;1h:30d",{timestamp="1360800000"}),"274,244",1,true))
    assert(string.find(m.slot("beer.ale;5m:2d",{timestamp="1361127300"}),"1526,756",1,true))
    m.process("./tests/fixtures/pale.mule")
--    m.flush_cache()
    assert(string.find(m.slot("beer.ale.pale;5m:2d",{timestamp="1361300362"}),"19,11",1,true))

    assert(string.find(m.slot("beer.ale.pale.rb;5m:2d",{timestamp="1361300428"}),"11,5",1,true))
    assert(string.find(m.slot("beer.ale;5m:2d",{timestamp="1361300362"}),"46,27",1,true))
  end

  for_each_db("pale",helper,true)
end

function test_key()
  local function helper(db)
    local m = mule(db)
    m.configure(table_itr({"beer 5m:48h 1h:30d 1d:3y"}))

    m.process("./tests/fixtures/pale.mule")
    m.flush_cache()
    assert(m.key("beer",{})==m.key("beer",{level=0}))

    -- there are 61 unique keys in pale.mule all are beer.pale sub keys
    -- (cut -d' ' -f 1 tests/fixtures/pale.mule  | sort | uniq | wc -l)
    local tests = {
      {0,1*3}, -- beer
      {1,2*3}, -- beer.ale
      {2,4*3}, -- beer.ale.{pale,brown}
      {3,(2+61)*3} -- beer, beer.ale and then the other keys
    }
    for i,t in ipairs(tests) do
      local g = m.graph("beer",{level=t[1],count=1000})
      local count = #split(g,";")-1
      assert_equal(t[2],count,i..": "..g)
    end

    local all_keys = string.match(m.key("beer",{level=4}),"%{(.+)%}")
    assert_equal(1+(61+2)*3,#split(all_keys,","))
    all_keys = string.match(m.key("beer",{level=4}),"%{(.+)%}")
    assert_equal(1+(61+2)*3,#split(all_keys,","))

    all_keys = string.match(m.key("beer",{level=1}),"{(.+)}")
    assert_equal(1+2*3,#split(all_keys,","))

  end
  for_each_db("key",helper,true)
end

function test_bounded_by_level()
  assert(bounded_by_level("hello.cruel.world","hello",2))
  assert_false(bounded_by_level("hello.cruel.world","hello",1))
  assert(bounded_by_level("hello.cruel.world","hello.cruel",1))
  assert(bounded_by_level("hello.cruel.world","hello.cruel.world",1))
  assert(bounded_by_level("hello.cruel.world","hello.cruel",12))
end


function test_duplicate_timestamps()
    local function helper(m)
      m.configure(n_lines(109,io.lines("./tests/fixtures/d_conf")))
      m.process(n_lines(109,io.lines("./tests/fixtures/d_input.mule")))
      for l in string_lines(m.dump("Johnston.Morfin",{to_str=true}).get_string()) do
        if #l>0 then
          assert_equal(4,#split(l," "),l)
        end
      end
    end
  for_each_db("test_duplicate_timestamps",helper)
end

function test_dashes_in_keys()
  local function helper(m)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
    assert(string.find(m.key("Johnston",{level=4}),"Sweet%-Nuthin"))
    assert(string.find(m.dump("Johnston.Emilia",{to_str=true}).get_string(),"Sweet%-Nuthin;1s:1m 78 1 300"))
    m.process("Johnston.Emilia.Sweet-Nuthin 2 300")
    assert(string.find(m.dump("Johnston.Emilia",{to_str=true}).get_string(),"Sweet%-Nuthin;1m:1h 80 2 300"))
  end
  for_each_db("test_dashes_in_keys",helper)
end

function test_stacked()
  function helper(db)
    local m = mule(db)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
--    repeat until not m.flush_cache()
    local level1 = m.graph("Johnston.Morfin",{level=1})
    local level2 = m.graph("Johnston.Morfin",{level=2})

    assert(string.find(level2,"Johnston.Morfin.Jamal.Marcela;1s:1m",1,true))
    assert(string.find(level2,"Johnston.Morfin.Jamal;1s:1m",1,true))
    assert_nil(string.find(level1,"Johnston.Morfin.Jamal.Marcela;1s:1m",1,true))
    assert(string.find(level1,"Johnston.Morfin.Jamal;1s:1m",1,true))
    assert(string.find(level1,"Johnston.Morfin.Jamal;1m:1h",1,true))

    level2 = m.graph("Johnston.Morfin;1m:1h",{level=2})
    level1 = m.graph("Johnston.Morfin;1m:1h",{level=1})


    assert(string.find(level2,"Johnston.Morfin.Jamal.Marcela;1m:1h",1,true))
    assert(string.find(level2,"Johnston.Morfin.Jamal;1m:1h",1,true))
    assert_nil(string.find(level2,"Johnston.Morfin.Jamal.Marcela;1s:1m",1,true))
    assert(string.find(level2,"Johnston.Morfin.Jamal.Marcela;1m:1h",1,true))
    assert(string.find(level1,"Johnston.Morfin.Jamal;1m:1h",1,true))
    assert_nil(string.find(level1,"Johnston.Morfin.Jamal;1h:12h",1,true))

    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=2,count=1}),
                             '{"version": 3,\n"data": {"Johnston.Morfin.Jamal;%d+%w:%d+%w": [[5,1,0]]\n}\n}'))

    local level0 = m.graph("Johnston.Morfin.Jamal;1m:1h",{level=0})
    assert(string.find(level0,"Johnston.Morfin.Jamal;1m:1h",1,true))
    assert_nil(string.find(level0,"Johnston.Morfin.Jamal.",1,true))

    level0 = m.graph("Johnston.Morfin.Jamal",{level=0})
    assert(string.find(level0,"Johnston.Morfin.Jamal;1m:1h",1,true))
    assert(string.find(level0,"Johnston.Morfin.Jamal;1h:12h",1,true))
    assert(string.find(level0,"Johnston.Morfin.Jamal;1s:1m",1,true))
    assert_nil(string.find(level0,"Johnston.Morfin.Jamal.",1,true))
  end
  for_each_db("stacked",helper,true)
end

function test_rank_output()
  local function helper(m)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=1}),'{"version": 3,\n"data": {"Johnston.Morfin.%w+;1h:12h": [[5,1,0]]\n}\n}'))
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=2,count=1}),'{"version": 3,\n"data": {"Johnston.Morfin.Jamal;%d+%w:%d+%w]+": [[5,1,0]]\n}\n}'))
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=2}),'{"version": 3,\n"data": {"Johnston.Morfin.%w+;1h:12h": [[5,1,0]]\n,"Johnston.Morfin.%w+;1m:1h": [[5,1,0]]\n}\n}'))
  end

  for_each_db("test_rank_output",helper)
end

function test_rank()
  local ts,r = update_rank_helper(0,0,100,20,10)
  assert_equal(100,ts)
  assert_equal(20,r)

  ts,r = update_rank_helper(ts,r,100,30,10)
  assert_equal(100,ts)
  assert_equal(50,r)

  ts,r = update_rank_helper(ts,r,110,10,10)
  assert_equal(110,ts)
  assert_equal(10+25,r)

  ts,r = update_rank_helper(ts,r,130,20,10)
  assert_equal(130,ts)
  assert_equal(20+35*0.25,r)

end

function test_caching()
  local function helper(m)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
    m.graph("Johnston.Morfin.Jamal.Marcela",{level=1,count=1})
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=1}),'{"version": 3,\n"data": {"Johnston.Morfin.Jamal;%w+": [[5,1,0]]\n}\n}'))
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=2}),'{"version": 3,\n"data": {"Johnston.Morfin.%w+;1h:12h": [[5,1,0]]\n,"Johnston.Morfin.%w;1m:1h": [[5,1,0]]\n}\n}'))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=1}),'{"version": 3,\n"data": {"Johnston.Morfin.%w+;1h:12h": [[10,2,0]]\n}\n}'))
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=2}),'{"version": 3,\n"data": {"Johnston.Morfin.%w+;1h:12h": [[10,2,0]]\n,"Johnston.Morfin.%w+;1m:1h": [[10,2,0]]\n}\n}'))
    --MAX_CACHE_SIZE = 1
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=1}),'{"version": 3,\n"data": {"Johnston.Morfin.%w+;1h:12h": [[15,3,0]]\n}\n}'))
    assert_equal(string.find(m.graph("Johnston.Morfin.Jamal",{level=1,count=2}),'{"version": 3,\n"data": {"Johnston.Morfin.%w+;1h:12h": [[15,3,0]]\n,"Johnston.Morfin.%w+;1m:1h": [[15,3,0]]\n}\n}'))
  end

  for_each_db("test_caching",helper)
end

function test_sparse_latest()
  local seq = sparse_sequence("beer.ale;1m:1h")

  seq.update(0,1,1)
  assert_equal(0,seq.slots()[1]._timestamp)

  seq.update(63,2,2)
  assert_equal(60,seq.slots()[1]._timestamp)
  assert_equal(2,seq.slots()[1]._hits)
  seq.update(3663,3,3)
  assert_equal(3660,seq.slots()[1]._timestamp)
  assert_equal(3,seq.slots()[1]._hits)
  assert_nil(seq.update(60,4,4))

  seq.update(141,5,5)
  assert_equal(120,seq.slots()[1]._timestamp)
  assert_equal(5,seq.slots()[1]._sum)
  seq.update(3687,6,6)
  assert_equal(9,seq.slots()[2]._sum)
end

function test_table_size()
  assert_equal(0,table_size({}))
  assert_equal(1,table_size({1}))
  assert_equal(1,table_size({a=1}))
  assert_equal(2,table_size({a=1,b=2}))
end

function test_bad_input_lines()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d","beer.ale 60s:24h"}))
    m.process("beer.ale.pale.012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789 7 4")
    m.process("beer.ale.;brown 6 54")
    m.process("6 54")

    assert_equal('{"version": 3,\n"data": {}\n}',m.graph("beer.ale;1m:12h"))
  end
  for_each_db("test_bad_input_lines",helper)
end

function test_concatenated_lines()
  local line = "beer.ale.brown 27 1427502724 9beer.stout.1.total 19 1427392373"
  local items,t = parse_input_line(line)

  assert_nil(legit_input_line(items[1],items[2],items[3],items[4]))
end

function test_uniq_factories()
  local function helper(m)
    m.configure(table_itr({"beer.ale 60s:12h 1h:30d 60s:12h 1h:30d 60s:12h 1h:30d","beer.ale 60s:24h"}))
    local factories = m.get_factories()
    assert_equal(3,table_size(factories["beer.ale"]))
    assert_equal(60,factories["beer.ale"][1][1])
    assert_equal(12*60*60,factories["beer.ale"][1][2])
  end
  for_each_db("test_uniq_factories",helper)
end

function test_distinct_prefixes()
  assert_nil(distinct_prefixes(nil))
  assert_equal(t2s({"cruel","hello","world"}),t2s(distinct_prefixes({"world","hello","cruel"})))
  assert_equal(t2s({"cruel","hello","world"}),t2s(distinct_prefixes({"world","hello","cruel","hello there"})))
  assert_equal(t2s({"cruel","hell","world"}),t2s(distinct_prefixes({"world","hello","cruel","hell"})))
  assert_equal(t2s({"cruel","hello","hoopla","world"}),t2s(distinct_prefixes({"world","hello","cruel","hoopla"})))
end

function test_drop_one_level()
  assert_nil(drop_one_level(nil))
  assert_equal("hello.cruel",drop_one_level("hello.cruel.world"))
  assert_equal("hello.cruel.",drop_one_level("hello.cruel..world"))
  assert_equal("hello",drop_one_level("hello.cruelworld"))
  assert_equal("",drop_one_level("hellocruelworld"))
  assert_equal("",drop_one_level(""))
end

function test_trim_to_level()
  assert_nil(trim_to_level(nil))
  assert_equal("hello.cruel",trim_to_level("hello.cruel.world","hello",1))
  assert_equal("hello.cruel.world",trim_to_level("hello.cruel.world.again","hello",2))
  assert_equal("hello.cruel.world",trim_to_level("hello.cruel.world.again","hello.cruel",1))
  assert_equal("hello.cruel.world",trim_to_level("hello.cruel.world","hello",2))
  assert_equal("hello.cruel.world",trim_to_level("hello.cruel.world","hello",4))
  assert_nil(trim_to_level("hello.cruel.world","bool",1))
  assert_equal("Johnston.Morfin.Jamal",trim_to_level("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema;1h:12h","Johnston.Morfin",1))
  assert_equal("Johnston.Morfin.Jamal.Marcela",trim_to_level("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema;1h:12h","Johnston.Morfin",2))
--  assert_equal("hello.cruel.",drop_one_level("hello.cruel..world"))
--  assert_equal("hello",drop_one_level("hello.cruelworld"))
--  assert_equal("",drop_one_level("hellocruelworld"))
--  assert_equal("",drop_one_level(""))
end

function test_in_memory_serialization()
  function helper(m)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
    local gr = m.graph("Johnston.Morfin.Jamal",{level=1,count=1,in_memory=true})
    if gr["Johnston.Morfin.Jamal;1h:12h"] then
      assert(arrays_equal({5,1,0},gr["Johnston.Morfin.Jamal;1h:12h"][1]))
    end
    gr = m.graph("Johnston.Emilia.Sweet-Nuthin",{level=1,count=1,in_memory=true})
    if gr["Johnston.Emilia.Sweet-Nuthin;1h:12h"] then
      assert(arrays_equal({78,1,0},gr["Johnston.Emilia.Sweet-Nuthin;1h:12h"][1]))
    end
  end
  for_each_db("test_in_memory_serialization",helper)
end

function test_find_keys()
  local function helper(m)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 5 10")
    m.process("Johnston.Emilia.Sweet-Nuthin 78 300")
    assert(string.find(m.key("",{substring="Nuthin"}),"Sweet-Nuthin",1,true))
    assert(string.find(m.key("Johnston",{substring="Nuthin"}),"Sweet-Nuthin",1,true))
    assert_nil(string.find(m.key("Johnston",{substring="nothing"}),"Sweet-Nuthin",1,true))
    assert_nil(string.find(m.key("Johnston.Emilia",{substring="Jama"}),"Jamal",1,true))
    assert(string.find(m.key("Johnston.Morfin.Jamal.Marcela",{substring="ulem"}),"Zulema",1,true))
    assert_nil(string.find(m.key("mal.Mar",{substring=true}),"Nuthin",1,true))
    assert(string.find(m.key("",{substring="lia.Sw"}),"Nuthin",1,true))
  end
  for_each_db("test_find_keys",helper)
end

function test_hits_provided()
  local function helper(m)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 8 10 4")
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 8 10 4")
    m.process("Johnston.Emilia.Sweet-Nuthin 50 300 100")
    local gr = m.graph("Johnston.Morfin.Jamal.Marcela.Emilia",{level=1,in_memory=true,stat="average"})
    assert(arrays_equal({2,8,0},gr["Johnston.Morfin.Jamal.Marcela.Emilia;1h:12h"][1]))
    gr = m.graph("Johnston.Morfin.Jamal.Marcela.Emilia",{level=1,in_memory=true})
    assert(arrays_equal({16,8,0},gr["Johnston.Morfin.Jamal.Marcela.Emilia;1h:12h"][1]))
    gr = m.graph("Johnston.Emilia.Sweet-Nuthin",{level=1,count=1,in_memory=true,stat="average"})
    assert(arrays_equal({0.5,100,0},gr["Johnston.Emilia.Sweet-Nuthin;1h:12h"][1]))
  end
  for_each_db("./tests/temp/test_find_keys",helper)
end

function test_factor()
  local function helper(m)
    m.configure(n_lines(110,io.lines("./tests/fixtures/d_conf")))
    m.process("Johnston.Morfin.Jamal.Marcela.Emilia.Zulema 8 10 4")
    m.process("Johnston.Emilia.Sweet-Nuthin 5 300 100")


    local gr = m.graph("Johnston.Morfin.Jamal.Marcela.Emilia",{level=1,in_memory=true,factor=10})
    assert(arrays_equal({0.8,4,0},gr["Johnston.Morfin.Jamal.Marcela.Emilia;1h:12h"][1]))
    gr = m.graph("Johnston.Morfin.Jamal.Marcela.Emilia",{level=1,in_memory=true})
    assert(arrays_equal({8,4,0},gr["Johnston.Morfin.Jamal.Marcela.Emilia;1h:12h"][1]))
    gr = m.graph("Johnston.Emilia.Sweet-Nuthin",{level=1,count=1,in_memory=true,factor=100})
    assert(arrays_equal({0.05,100,0},gr["Johnston.Emilia.Sweet-Nuthin;1h:12h"][1]))
  end
  for_each_db("./tests/temp/test_find_keys",helper)

end

function test_same_prefix()
  local function helper(m)
    m.configure(table_itr({"beer 60s:12h 1h:30d","bee 1h:30d"}))
    m.process("beer.ale.pale 7 4")

    local gr = m.graph("beer",{})
    assert(string.find(gr,'"beer;1h:30d": [[7,1,0]]',1,true)) -- both bee and beer define 1h:30d
    assert(string.find(gr,'"beer;1m:12h": [[7,1,0]]',1,true))
    gr = m.graph("beer.ale.pale",{})
    assert(string.find(gr,'"beer.ale.pale;1h:30d": [[7,1,0]]',1,true)) -- both bee and beer define 1h:30d
    assert(string.find(gr,'"beer.ale.pale;1m:12h": [[7,1,0]]',1,true))
    assert_nil(string.find(gr,'"beer;1m:1d": [[7,1,0]]',1,true))
  end
  for_each_db("./tests/temp/test_same_prefix",helper)
end


--verbose_log(true)
--profiler.start("profiler.out")
