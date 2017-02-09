
local lunit = require "lunit"
require "tests.strict"

if _VERSION >= 'Lua 5.2' then
  _ENV = lunit.module('test_indexer','seeall')
else
  module( "test_indexer", lunit.testcase,package.seeall )
end
require "indexer"
require "helpers"

local function rows_to_list(func)
  local t = {}
  for r in func() do
    t[#t+1] = r
  end
  return t
end

local function search_as_list(ind,query)
  local t = {}
  for r in ind.search(query) do
    t[#t+1] = r
  end
  return t
end

local function the_tests(ind)
  ind.insert({
      "beer.ale.pale",
      "beer.stout.irish",
      "beer.stout.irish",
      "wine.pinotage.south_africa",
  })
  local t = rows_to_list(ind.dump)
  assert_equal(3,#t)

  t = search_as_list(ind,"stout")
  assert_equal(1,#t)
  assert_equal("beer.stout.irish",t[1])

  t = search_as_list(ind,"stt")
  assert_equal(0,#t)

  t = search_as_list(ind,"beer")
  assert_equal(2,#t)

  assert_equal(1,#search_as_list(ind,"south"))
end

function test_simple()
  the_tests(indexer())
end

function test_with_path()
  the_tests(indexer("./tests/temp/with_path"))
end


--verbose_log(true)
