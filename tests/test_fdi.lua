require "tests.strict"
require "lunit"
module( "test_fdi", lunit.testcase,package.seeall )

package.path=package.path..";./fdi/?.lua"
function test_external_fdi()
  require "testDailyAlg"
  require "testHourlyAlg"
  require "testMinutelyAlg"
end
