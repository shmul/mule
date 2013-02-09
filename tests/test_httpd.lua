require "tests.strict"
require "lunit"
require "httpd"
module( "test_httpd", lunit.testcase,package.seeall )
local cdb = require "column_db"

local function column_db_factory(name_)
  os.execute("rm -rf "..name_.."_cdb")
  os.execute("mkdir -p "..name_.."_cdb")
  return cdb.column_db(name_.."_cdb")
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
  local db = column_db_factory("./tests/temp/alerts")
  local m = mule(db)
  local res = {}
  local req = {
    verb = "GET",
    url = "alert",
    protocol = "HTTP/1.0",
  }
  send_response(fake_send(res),req,nil,
                function(callback_) return callback_(m) end)
  assert(string.find(res.body,'"data": {}',1,true))

  req.verb = "POST"
  send_response(fake_send(res),req,nil,
                function(callback_) return callback_(m) end)
  assert(string.find(res.headers,'405',1,true))
  assert_nil(res.body)

  req.verb = "POST"
  req.url = "alert/beer.ale;5m:12h"
  send_response(fake_send(res),req,"critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m",
                function(callback_) return callback_(m) end)
  assert(string.find(res.headers,'405',1,true))
  assert_nil(res.body)

  req.verb = "PUT"
  send_response(fake_send(res),req,"critical_high=100&warning_high=80&warning_low=20&critical_low=0&stale=6m&period=10m",
                function(callback_) return callback_(m) end)
  assert(string.find(res.headers,'201',1,true))
  assert_nil(res.body)

  req.verb = "GET"
  req.url = "alert/beer.ale;5m:12h"
  send_response(fake_send(res),req,nil,
                function(callback_) return callback_(m) end)
  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,360,0,"stale"]}',1,true))

  -- hehe, just now we are really configuring mule
  m.configure(table_itr({"beer.ale 5m:12h 1h:30d"}))
  m.process("beer.ale.brown.newcastle 12 "..os.time())
  req.verb = "GET"
  req.url = "alert/beer.ale;5m:12h"
  send_response(fake_send(res),req,nil,
                function(callback_) return callback_(m) end)
  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,360,12,"WARNING LOW"]}',1,true))

  m.process("beer.ale.brown.newcastle 20 "..os.time())

  send_response(fake_send(res),req,nil,
                function(callback_) return callback_(m) end)

  assert(string.find(res.body,'"data": {"beer.ale;5m:12h": [0,20,80,100,360,32,"NORMAL"]}',1,true))
end