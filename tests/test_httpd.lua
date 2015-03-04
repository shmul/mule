require "tests.strict"
require "lunit"
require "mule"
module( "test_httpd", lunit.testcase,package.seeall )
local cdb = require "column_db"
local p = require "purepack"

local function column_db_factory(name_)
  p.set_pack_lib("bits")
  local dir = create_test_directory(name_.."_cdb")
  return cdb.column_db(dir)
end


local function table_itr(tbl_)
  local current = 0
  return function()
		   current = current + 1
		   return tbl_[current]
		 end
end

local function fake_send(response_)
  return function(headers_,body_)
    response_.headers = headers_
    response_.body = body_
         end
end

function test_alerts()
  local db = column_db_factory("alerts")
  local m = mule(db)
  local res = {}

  local function request(verb_,url_,body_)
    local res = {}
    local req = {
      verb = verb_,
      url = url_,
      protocol = "HTTP/1.0",
    }
    send_response(fake_send(res),function() end,req,body_,
                  function(callback_) return callback_(m) end)

    return res
  end

  res = request("GET","alert")
  assert(string.find(res.headers,'Content-Type: application/json',1,true))
  assert(string.find(res.body,'"data": {"anomalies": {}}',1,true))

  res = request("POST","alert")
  assert(string.find(res.headers,'405',1,true))
  assert_nil(res.body)

  res = request("POST","alert/beer.ale;5m:12h","critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m")
  assert(string.find(res.headers,'405',1,true))
  assert_nil(res.body)

  res = request("PUT","alert/beer.ale","critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m")
  assert(string.find(res.headers,'400',1,true))
  assert_nil(res.body)

  res = request("PUT","alert","critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m&period=10m")
  assert(string.find(res.headers,'400',1,true))
  assert_nil(res.body)

  res = request("PUT","alert/beer.ale;5m:12h","critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m&period=10m")
  assert(string.find(res.headers,'201',1,true))
  assert_nil(string.find(res.headers,'Content-Type: application/json',1,true))
  assert_nil(res.body)

  -- testing idempotent
  res = request("PUT","alert/beer.ale;5m:12h","critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m&period=10m")
  assert(string.find(res.headers,'201',1,true))
  assert_nil(res.body)

  res = request("GET","alert/beer.ale;5m:12h")
  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,600,360,0,"stale"',1,true))
  assert(string.find(res.headers,'Content-Type: application/json',1,true))
  -- testing idempotent once more to see that the state didn't change
  res = request("PUT","alert/beer.ale;5m:12h","critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m&period=10m")
  assert(string.find(res.headers,'201',1,true))
  assert_nil(res.body)

  res = request("GET","alert/beer.ale;5m:12h")
  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,600,360,0,"stale"',1,true))

  -- hehe, just now we are really configuring mule
  m.configure(table_itr({"beer.ale 5m:12h 1h:30d"}))
  m.process("beer.ale.brown.newcastle 12 "..os.time())
  res = request("GET","alert/beer.ale;5m:12h")
  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,600,360,12,"WARNING LOW"',1,true))

  m.process("beer.ale.brown.newcastle 20 "..os.time())

  res = request("GET","alert/beer.ale;5m:12h")
  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,600,360,32,"NORMAL"',1,true))

  -- testing idempotent once again
  res = request("PUT","alert/beer.ale;5m:12h","critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m&period=10m")
  assert(string.find(res.headers,'201',1,true))
  assert(string.find(res.headers,'Location: ./beer.ale;5m:12h',1,true))
  assert_nil(res.body)

  res = request("GET","alert/beer.ale;5m:12h")
  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,600,360,32,"NORMAL"',1,true))

  res = request("DELETE","alert/beer.ale;5m:12h")
  assert(string.find(res.headers,'204'))

  res = request("GET","alert")
  assert(string.find(res.body,'"data": {"anomalies": {}}',1,true))

  res = request("PUT","alert/beer.ale.brown;5m:12h","critical_high=18&warning_high=16&warning_low=8&critical_low=4&stale=6m&period=10m")
  assert(string.find(res.headers,'201',1,true))
  assert(string.find(res.headers,'Location: ./beer.ale.brown;5m:12h',1,true))
  assert_nil(res.body)

  res = request("GET","alert")
  assert(string.find(res.body,'"data": {"beer.ale.brown;5m:12h": [4,8,16,18,600,360,32,"CRITICAL HIGH"',1,true))

  res = request("PUT","alert/beer.stout;1d:14d","critical_high=900&warning_high=800&warning_low=100&critical_low=34&stale=2d&period=1d")
  assert(string.find(res.headers,'201',1,true))
  assert_nil(res.body)

  res = request("PUT","alert/beer.ale.pale;5m:12h","critical_high=100&warning_high=80&warning_low=3&critical_low=-1&stale=6m&period=10m")
  m.process("beer.ale.pale 1 "..os.time())
  assert(string.find(res.headers,'Location: ./beer.ale.pale;5m:12h',1,true))
  res = request("GET","alert")

  assert(string.find(res.body,'"beer.ale.pale;5m:12h": [-1,3,80,100,600,360,1,"WARNING LOW"',1,true))
  m.process("beer.ale.pale 101 "..os.time())
  res = request("GET","alert")

  assert(string.find(res.body,'"beer.ale.pale;5m:12h": [-1,3,80,100,600,360,102,"CRITICAL HIGH"',1,true))

  res = request("GET","alert")

  assert(string.find(res.body,'"beer.ale.brown;5m:12h": [4,8,16,18,600,360,32,"CRITICAL HIGH"',1,true))
  assert(string.find(res.body,'"beer.stout;1d:14d": [34,100,800,900,86400,172800,0,"stale"',1,true))

  assert_nil(string.find(res.headers,'Access-Control-Allow-Origin: *',1,true))

  res = request("GET","graph/beer?level=1&alerts=true")
  assert(string.find(res.body,'"alerts": {"beer.stout;1d:14d": [34,100,800,900,86400,172800,0,"stale"',1,true))

  res = request("OPTIONS","graph/beer?alerts=true")
  assert(string.find(res.headers,'Access-Control-Allow-Origin: *',1,true))


  -- todo add alert for a graph that has holes in it (i.e. slots that weren't updated recently)
end

function test_kvs()
  local db = column_db_factory("kvs")
  local m = mule(db)
  local res = {}

  local function request(verb_,url_,body_)
    local res = {}
    local req = {
      verb = verb_,
      url = url_,
      protocol = "HTTP/1.0",
    }
    send_response(fake_send(res),function() end,req,body_,
                  function(callback_) return callback_(m) end)

    return res
  end

  res = request("GET","kvs/ttb")
  assert_nil(res.body)
  assert_nil(string.find(res.headers,'Content-Type: application/json',1,true))

  res = request("POST","kvs/ttb","it's so heavy")
  assert(string.find(res.headers,'201',1,true))

  res = request("GET","kvs/ttb")
  assert_equal("it's so heavy",res.body)
  assert(string.find(res.headers,'Content-Type: application/json',1,true))
  res = request("PUT","kvs/ttb","yes it is")
  assert(string.find(res.headers,'201',1,true))

  res = request("PUT","kvs/band","i know")
  assert(string.find(res.headers,'201',1,true))
  assert_nil(string.find(res.headers,'Content-Type: application/json',1,true))

  res = request("GET","kvs/ttb")
  assert_equal("yes it is",res.body)

  res = request("DELETE","kvs/ttb")
  assert_nil(res.body)

  res = request("GET","kvs/ttb")
  assert_nil(res.body)

  res = request("GET","kvs/band")
  assert_equal("i know",res.body)

end

--verbose_log(true)
