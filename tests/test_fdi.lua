require "tests.strict"
require 'fdi/calculate_fdi'

local lunit = require "lunit"
if _VERSION >= 'Lua 5.2' then
    _ENV = lunit.module('test_fdi','seeall')
else
  module( "test_fdi", lunit.testcase,package.seeall )
end


function test_illegal_intervals()
  assert_nil(calculate_fdi(os.time(),50,{}))
end
