require "tests.strict"

if _VERSION >= 'Lua 5.2' then
  _ENV = lunit.module('test_strict','seeall')
else
  module( "test_strict", lunit.testcase,package.seeall )
end
require "lunit"


function test_dummy()
end
