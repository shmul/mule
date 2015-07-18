require "tests.strict"

local lunit = require "lunitx"
if _VERSION >= 'Lua 5.2' then
    _ENV = lunit.module('test_fdi','seeall')
else
  module( "test_fdi", lunit.testcase,package.seeall )
end



package.path=package.path..";./fdi/?.lua"
function test_external_fdi()
  require "testDailyAlg"
  require "testHourlyAlg"
  require "testMinutelyAlg"
end
