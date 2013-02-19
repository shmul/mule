require "mulelib"
require "tests.strict"

require "lunit"
require "tokyocabinet"
require "tc_store"
require "memory_store"

module( "test_mulelib", lunit.testcase,package.seeall )

local function tokyocabinet_db(name_)
  os.remove(name_)
  local bdb = tokyocabinet.bdbnew()
  assert(bdb:open(name_,bdb.OWRITER+bdb.OCREAT))
  return bdb
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
  local str = "hello\n\cruel\nworld"
  local lines = {}
  for i in string_lines(str) do
	table.insert(lines,i)
  end

  assert_equal(lines[1],"hello")
  assert_equal(lines[2],"cruel")
  assert_equal(lines[3],"world")

end

function test_calculate_slot()
  local tests = {
	-- {step,period,timestamp,slot,adjust-timestamp}
	{1,60,0,1,0},
	{1,60,60,1,60},
	{2,60,61,1,60},
	{2,60,121,1,120},
	{2,60,121,1,120},
	{2,60,123,2,122},
  }

  for i,t in ipairs(tests) do
	local slot,adjusted = calculate_slot(t[3],t[1],t[2])
	assert_equal(t[4],slot,i)
	assert_equal(t[5],adjusted,i)
  end
end


function helper_time_sequence(store_)
  local step,period = parse_time_pair("1m:60m")
  assert_equal(60,step)
  assert_equal(3600,period)

  local seq = sequence("seq")
  local store = store_("seq")
  store.create("seq",step,period)
  seq.init(step,period,store)
  assert_equal(1,seq.find_slot(0))
  assert_equal(1,seq.find_slot(59))
  assert_equal(2,seq.find_slot(60))
  assert_equal(6,seq.find_slot(359))
  assert_equal(7,seq.find_slot(360))

  seq.update(0,10,1)
  assert_equal(10,seq.get_slot(1)._sum)
  assert_equal(10,seq.get_slot(seq.latest())._sum)
  seq.update(1,17,1)
  assert_equal(27,seq.get_slot(1)._sum)
  assert_equal(2,seq.get_slot(1)._hits)
  assert_equal(27,seq.get_slot(seq.latest())._sum)
  seq.update(3660,3,1)
  assert_equal(3,seq.get_slot(2)._sum)
  assert_equal(3,seq.get_slot(seq.latest())._sum)
  seq.update(60,7,1) -- this is in the past and should be discarded
  assert_equal(3,seq.get_slot(2)._sum)
  assert_equal(1,seq.get_slot(2)._hits)
  assert_equal(3,seq.get_slot(seq.latest())._sum)
  seq.update(7260,89,1)
  assert_equal(89,seq.get_slot(2)._sum)
  assert_equal(1,seq.get_slot(2)._hits)
  assert_equal(89,seq.get_slot(seq.latest())._sum)

  --seq.serialize(stdout(", "))
  local tbl = {}
  seq.serialize(tableout(tbl),{deep=true})
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

  local seq1 = sequence("seq")
  assert_equal("seq",seq1.deserialize(tablein(tbl),in_memory_store,true))
  local tbl1 = {}
  seq1.serialize(tableout(tbl1),{deep=true})
  for i,v in ipairs(tbl) do
	assert_equal(v,tbl1[i],i)
  end

  seq.update(10799,43,1)
  assert_equal(43,seq.get_slot(60)._sum)
  assert_equal(1,seq.get_slot(60)._hits)

  seq.update(10800,99,1)
  assert_equal(99,seq.get_slot(1)._sum)
  assert_equal(1,seq.get_slot(1)._hits)
  --seq.serialize(stdout(", "))
  tbl = {}
  seq.serialize(tableout(tbl),{sorted=true,deep=true})
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
  helper_time_sequence(in_memory_store)
  helper_time_sequence(function(metric_,step_,period_)
						 local db = "./tests/temp/test_sequences.bdb"
						 tokyocabinet_db(db):close()
						 return tokyocabinet_store(db,metric_,step_,period_)
					   end)
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
  local items = parse_input_line("event.phishing 60S:12H 1H:30d")
  assert_equal(3,#items)
  assert_equal("event.phishing",items[1])
end

function test_factories()
  local m = mule(in_memory_sequences(in_memory_store))
  m.configure(table_itr({"event.phishing 60s:12h 1h:30d","event.phishing 60s:24h"}))

  assert_equal(3,#m.get_factories()["event.phishing"])
  local factories = m.get_factories()
  assert(factories["event.phishing"])
  assert_equal(0,#m.matching_sequences("event.phishing"))
  assert_equal(0,#m.matching_sequences("event.phishing.google.com"))

  assert_equal(0,#m.factory("event"))
  assert_equal(3,#m.factory("event.phishing"))
  assert_equal(6,#m.factory("event.phishing.google"))
  assert_equal(9,#m.factory("event.phishing.google.com"))
  -- the "event.phishing" part matches
  assert_equal(9,#m.factory("event.phishing.yahoo.com"))
  assert_equal(3,#m.factory("event.phishing"))

end


local function sequence_any(seq_,callback_)
  local out = {}
  seq_.serialize(tableout(out),{deep=true})
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
	if not non_empty_sequence(m) then return false end
  end
  return true
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
  local m = mule(in_memory_sequences(in_memory_store))
  m.configure(table_itr({"event.phishing 60s:12h 1h:30d","event.pharming 3m:1h","event.akl 10m:1y"}))
  local seqs = m.get_sequences()
  assert(not seqs.get("event.phishing"))
  local factories = m.get_factories()
  assert(factories["event.phishing"])
  assert(factories["event.pharming"])
  assert(not factories["event.out_of_range"])
  assert_equal(1,#factories["event.pharming"])
  assert_equal(2,#factories["event.phishing"])
  assert_equal(nil,factories["event.phishing.google.com"])

  m.process("event.phishing.phishing-host 20 74857843")

  assert(empty_metrics(seqs.get("event.pharming")))

  assert(empty_metrics(seqs.get("event.phishing.google.com")))
  assert(non_empty_metrics(seqs.get("event.phishing.phishing-host")))

  m.process("event.phishing.google.com 98 74857954")
  assert(seqs.get("event.phishing.google.com"))

  assert(non_empty_metrics(seqs.get("event.phishing.google.com")))

  m.process("event.pharming.pigs.pharm.com 98 74857954")
  assert(non_empty_metrics(seqs.get("event.pharming.pigs.pharm.com")))
  assert(non_empty_metrics(seqs.get("event.pharming")))
  assert(empty_metrics(seqs.get("event.akl")))


  m.process("event.pharming 143 74858731")
  assert(non_empty_metrics(seqs.get("event.pharming")))
end

function test_top_level_factories()

  function helper(m)
	m.configure(table_itr({"event. 60s:12h 1h:30d","event 3m:1h"}))
	local seqs = m.get_sequences()
	assert(not seqs.get("event.phishing"))
	local factories = m.get_factories()
	assert_equal(1,table_size(factories))
	assert(factories["event"])
	assert(not factories["event.out_of_range"])
	assert_equal(nil,factories["event.phishing"])
	assert_equal(nil,factories["event.phishing.google.com"])

    m.process({"event.phishing.phishing-host 20 74857843","event.phishing.phishing-host.jom 20 74857843","event.phishing.phishing-host.foo 30 74857843"})

	assert(empty_metrics(seqs.get("event.pharming")))

	assert(empty_metrics(seqs.get("event.phishing.google.com")))
	assert(non_empty_metrics(seqs.get("event")))
	assert(non_empty_metrics(seqs.get("event.phishing")))
	assert(non_empty_metrics(seqs.get("event.phishing.phishing-host")))
	assert(string.find(m.latest("event"),"20,1,74857800"))
	assert(string.find(m.latest("event.phishing"),"20,1,74857800"))

    m.process("event.phishing.phishing-host 9 74857860")
	assert(string.find(m.latest("event.phishing"),"9,1,74857860"))

    m.process("event.phishing.phishing-host 11 74861443")
    m.process("event.phishing.phishing-host 7 74861444")
	assert(string.find(m.latest("event.phishing"),"18,2,74858400"))

	m.process("event.phishing.google.com 98 74857954")
	assert(seqs.get("event.phishing.google.com"))
	assert(non_empty_metrics(seqs.get("event.phishing.google.com")))

	m.process("event.pharming.pigs.pharm.com 98 74857954")
	assert(non_empty_metrics(seqs.get("event.pharming.pigs.pharm.com")))
	assert(non_empty_metrics(seqs.get("event.pharming")))
	assert(empty_metrics(seqs.get("event.akl")))


	m.process("event.pharming 143 74858731")
	assert(non_empty_metrics(seqs.get("event.pharming")))
  end

  local m = mule(in_memory_sequences(in_memory_store))
  helper(m)
  local bdb = tokyocabinet_db("./tests/temp/top_level.bdb")
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()
  tc_init(bdb)
  m = mule(tokyocabinet_sequences(
			 function(metric_,step_,period_)
			   return tokyocabinet_store(bdb,metric_,step_,period_)
			 end,tc_get,tc_fwmkeys))
  helper(m)
end



function test_reset()
  function helper(m)
	m.configure(table_itr({"event 60s:12h 1h:30d","event.pharming 3m:1h"}))
	assert(not m.get_sequences().get("event.phishing"))
	local factories = m.get_factories()
	assert(factories["event.pharming"])

	assert_equal(0,#m.matching_sequences("event.pharming"))
	assert_equal(0,#m.matching_sequences("event.phishing.google.com"))

	m.process("event.phishing.phishing-host 20 74857843")
	assert(non_empty_metrics(m.get_sequences().get("event")))
	assert(empty_metrics(m.get_sequences().get("event.pharming")))
	assert(2,#m.matching_sequences("event.phishing"))
	assert(2,#m.matching_sequences("event.phishing.phishing-host"))

	assert(empty_metrics(m.get_sequences().get("event.phishing.google.com")))
	assert(non_empty_metrics(m.get_sequences().get("event.phishing.phishing-host")))

	m.process("event.phishing.google.com 98 74857954")
	assert(m.get_sequences().get("event.phishing.google.com"))
	assert(non_empty_metrics(m.get_sequences().get("event.phishing.google.com")))

	m.process("event.pharming.pigs.pharm.com 98 74857954")
	assert(non_empty_metrics(m.get_sequences().get("event.pharming.pigs.pharm.com")))
	assert(non_empty_metrics(m.get_sequences().get("event.pharming")))


	m.process("event.pharming 143 74858731")
	assert(non_empty_metrics(m.get_sequences().get("event.pharming")))
	assert(non_empty_metrics(m.get_sequences().get("event")))

	m.process(".reset event.pharming")
	assert(non_empty_metrics(m.get_sequences().get("event")))
	assert(empty_metrics(m.get_sequences().get("event.pharming")))
	assert(empty_metrics(m.get_sequences().get("event.phishing.pigs.pharm.com")))
	assert(non_empty_metrics(m.get_sequences().get("event.phishing.google.com")))


	m.process(".reset event.phishing")
	assert(non_empty_metrics(m.get_sequences().get("event")))
	assert(empty_metrics(m.get_sequences().get("event.phishing")))
	assert(empty_metrics(m.get_sequences().get("event.phishing.google")))
	assert(empty_metrics(m.get_sequences().get("event.phishing.google.com")))
  end

  local m = mule(in_memory_sequences(in_memory_store))
  helper(m)
  local bdb = tokyocabinet_db("./tests/temp/reset.bdb")
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()
  tc_init(bdb)
  m = mule(tokyocabinet_sequences(
					  function(metric_,step_,period_)
						return tokyocabinet_store(bdb,metric_,step_,period_)
					  end,tc_get,tc_fwmkeys))
  helper(m)
end

function test_save_load()
  local m = mule(in_memory_sequences(in_memory_store))

  m.configure(table_itr({"event.phishing 60s:12h 1h:30d","event.pharming 3m:1h"}))
   m.process("event.phishing.phishing-host 20 74857843")
   m.process("event.phishing.google.com 98 74857954")
   m.process("event.pharming.pigs.pharm.com 98 74857954")
   m.process("event.pharming 143 74858731")

  local out = strout()
  m.serialize(out)
  local n = mule(in_memory_sequences(in_memory_store))
  n.deserialize(strin(out.get_string()))
end


function test_process_tokyo()
  local bdb = tokyocabinet_db("./tests/temp/process_tokyo.bdb")
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()
  tc_init(bdb)
  local m = mule(tokyocabinet_sequences(
					  function(metric_,step_,period_)
						return tokyocabinet_store(bdb,metric_,step_,period_)
					  end,tc_get,tc_fwmkeys))

  m.configure(table_itr({"event.phishing 60s:12h 1h:30d","event.pharming 3m:1h","event.akl 10m:1y"}))
  local seqs = m.get_sequences()
  assert(not seqs.get("event.phishing"))
  local factories = m.get_factories()
  assert(factories["event.phishing"])
  assert(factories["event.pharming"])
  assert(not factories["event.out_of_range"])
  assert_equal(1,#factories["event.pharming"])
  assert_equal(2,#factories["event.phishing"])
  assert_equal(nil,factories["event.phishing.google.com"])

  m.process("event.phishing.phishing-host 20 74857843")

  assert(empty_metrics(seqs.get("event.pharming")))

  assert(empty_metrics(seqs.get("event.phishing.google.com")))
  assert(non_empty_metrics(seqs.get("event.phishing.phishing-host")))

  m.process("event.phishing.google.com 98 74857954")
  assert(seqs.get("event.phishing.google.com"))
  assert(non_empty_metrics(seqs.get("event.phishing.google.com")))

  m.process("event.pharming.pigs.pharm.com 98 74857954")
  assert(non_empty_metrics(seqs.get("event.pharming.pigs.pharm.com")))
  assert(non_empty_metrics(seqs.get("event.pharming")))
  assert(empty_metrics(seqs.get("event.akl")))


  m.process("event.pharming 143 74858731")
  assert(non_empty_metrics(seqs.get("event.pharming")))

end

function test_latest()
  os.remove("./tests/temp/process.bdb")
  local bdb = tokyocabinet.bdbnew()
  assert(bdb:open("./tests/temp/process.bdb",bdb.OWRITER+bdb.OCREAT))
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()
  tc_init(bdb)
  local m = mule(tokyocabinet_sequences(
					  function(metric_,step_,period_)
						return tokyocabinet_store(bdb,metric_,step_,period_)
					  end,tc_get,tc_fwmkeys))

  m.configure(table_itr({"event.phishing 60s:12h 1h:30d","event.pharming 3m:1h","event.akl 10m:1y"}))

  m.process("event.phishing.google 3 3")
  assert(string.find(m.latest("event.phishing.google;1m:12h"),"3,1,0"))
  assert(string.find(m.graph("event.phishing.google;1m:12h","latest"),"3,1,0"))
  assert(string.find(m.slot("event.phishing.google;1m:12h","1"),"3,1,0"))
  assert_nil(m.latest("event.phishing.yahoo;1m:12h"))
  assert_nil(m.graph("event.phishing.yahoo;1m:12h","latest"))
  assert_nil(m.latest("event.phishing.yahoo;1h:30d"))


  -- the timestamp is adjusted
  assert(string.find(m.latest("event.phishing.google"),"3,1,0"))
  assert(string.find(m.latest("event.phishing.google;1m:12h"),"3,1,0"))


  m.process("event.phishing.yahoo 2 3601")
  assert(string.find(m.latest("event.phishing.google;1m:12h"),"3,1,0"))
  assert(string.find(m.graph("event.phishing.google;1m:12h","latest-90"),"0,0,0"))
  assert(string.find(m.graph("event.phishing.yahoo;1m:12h","3604"),"2,1,3600"))
  assert(string.find(m.graph("event.phishing.yahoo;1m:12h","latest+10s"),"2,1,3600"))
  assert_nil(string.find(m.graph("event.phishing.yahoo;1m:12h","latest+10m,now"),"2,1,3600"))
  assert(string.find(m.graph("event.phishing.yahoo;1m:12h","latest+10m"),"0,0,0"))
  assert(string.find(m.latest("event.phishing;1h:30d"),"2,1,3600"))

  m.process("event.phishing.yahoo 7 4")
  -- the latest is not affected
  assert(string.find(m.latest("event.phishing;1h:30d"),"2,1,3600"))
  assert(string.find(m.graph("event.phishing.yahoo;1h:30d","latest-56m"),"7,1,0"))
  -- lets check the range
  local g = m.graph("event.phishing.yahoo;1h:30d","0..latest")
  assert(string.find(g,"2,1,3600"))
  assert(string.find(g,"7,1,0"))
  g = m.graph("event.phishing.yahoo;1h:30d","latest..0")
  assert(string.find(g,"[[2,1,3600,],[7,1,0,],]"))
  m.process("event.phishing.yahoo 9 64")
  g = m.graph("event.phishing.yahoo;1m:12h","latest..0")
  assert(string.find(g,"[[2,1,3600,],[9,1,60,],[7,1,0,],]"))

  m.process("event.phishing.google 90 4400")
  assert(string.find(m.latest("event.phishing;1h:30d"),"92,2,3600"))
  -- we have two hits 3+7 at times 3 and 4 which are adjusted to 0


  m.process("event.phishing.google 77 7201")
  assert_nil(string.find(m.graph("event.phishing;1h:30d","latest,latest-2h"),"92,2,3600"))
  assert(string.find(m.graph("event.phishing;1h:30d","latest-3m"),"92,2,3600"))
end

function test_update_only_relevant()
  local bdb = tokyocabinet_db("./tests/temp/update_only_relevant.bdb")
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()
  tc_init(bdb)
  local m = mule(tokyocabinet_sequences(
					  function(metric_,step_,period_)
						return tokyocabinet_store(bdb,metric_,step_,period_)
					  end,tc_get,tc_fwmkeys))

  m.configure(table_itr({"event.phishing 60s:12h 1h:30d","event.pharming 3m:1h","event.akl 10m:1y"}))

  m.process("event.phishing.yahoo 7 4")
  m.process("event.phishing.google 6 54")
  assert(string.find(m.latest("event.phishing;1m:12h"),"13,2,0"))


  m.process("event.phishing.apple 32 91")

  assert(string.find(m.latest("event.phishing.yahoo;1m:12h"),"7,1,0"))
  assert(string.find(m.latest("event.phishing.google;1m:12h"),"6,1,0,"))
  assert(string.find(m.latest("event.phishing.apple;1m:12h"),"32,1,60,"))
  assert(string.find(m.latest("event.phishing;1m:12h"),"32,1,60,"))
  assert(string.find(m.slot("event.phishing.apple;1m:12h","93"),"32,1,60,"))

  m.process("event.phishing 132 121")
  assert(string.find(m.slot("event.phishing;1m:12h","121"),"132,1,120,"))
  assert(string.find(m.latest("event.phishing;1m:12h"),"132,1,120,"))
  assert(string.find(m.latest("event.phishing.yahoo;1m:12h"),"7,1,0,"))
  assert(string.find(m.latest("event.phishing.google;1m:12h"),"6,1,0,"))
  assert(string.find(m.latest("event.phishing.apple;1m:12h"),"32,1,60,"))

end


function test_metric_one_level_childs()
  local bdb = tokyocabinet_db("./tests/temp/one_level_childs.bdb")
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()
  tc_init(bdb)
  local m = mule(tokyocabinet_sequences(
					  function(metric_,step_,period_)
						return tokyocabinet_store(bdb,metric_,step_,period_)
					  end,tc_get,tc_fwmkeys))

  m.configure(table_itr({"event.phishing 60s:12h 1h:30d","event.pharming 3m:1h","event.akl 10m:1y"}))

  m.process("event.phishing.yahoo 7 4")
  m.process("event.phishing.yahoo.hello 7 4")
  m.process("event.phishing.yahoo.hello.cruel 7 4")
  m.process("event.phishing.google 6 54")
  m.process("event.phishing.google.world 6 54")
  m.process("event.phishing.apple 32 91")
  m.process("event.phishing 132 121")

  local tests = {
	{"event.phishing.google;1h:30d",1},
	{"event.phishing;1m:12h",3},
	{"event;1m:12h",1},
	{"",0},
	{"foo",0},
  }

  for j,t in ipairs(tests) do
	local childs = {}

	for i in metric_one_level_childs(m.get_sequences(),t[1]) do
	  table.insert(childs,i)
	end
	assert_equal(t[2],#childs,j)
  end

end

function test_chrome_crash()
  local bdb = tokyocabinet_db("./tests/temp/chrome_crash.bdb")
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()
  tc_init(bdb)
  local m = mule(tokyocabinet_sequences(
					  function(metric_,step_,period_)
						return tokyocabinet_store(bdb,metric_,step_,period_)
					  end,tc_get,tc_fwmkeys))

  m.configure(table_itr({"agentevents. 5m:48h 1h:30d 1d:3y"}))

  m.process("./tests/fixtures/chrome_crash.dump")
  assert(string.find(m.slot("agentevents.events_types.chrome_crash;1h:30d","1360800000"),"274,244",1,true))
  assert(string.find(m.slot("agentevents.events_types;5m:2d","1361127300"),"1526,756",1,true))
  m.process("./tests/fixtures/crash.mule")
  assert(string.find(m.slot("agentevents.events_types.chrome_crash;5m:2d","1361300362"),"19,11",1,true))

  assert(string.find(m.slot("agentevents.events_types.chrome_crash.rbs1;5m:2d","1361300428"),"11,5",1,true))
  assert(string.find(m.slot("agentevents.events_types;5m:2d","1361300362"),"46,27",1,true))

end

--verbose_log(true)