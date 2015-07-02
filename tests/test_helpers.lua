require "tests.strict"
require "helpers"

module( "test_helpers", lunit.testcase,package.seeall )

function test_file_exists()
  assert_true(file_exists("tests/fixtures/mule.cfg"))
  assert_false(file_exists("tests/fixtures/no-such-file"))
end

function test_file_size()
  assert_equal(53, file_size("tests/fixtures/mule.cfg"))
  assert_false(file_size("tests/fixtures/no-such-file"))
end

function test_directory_exists()
  assert_true(directory_exists("tests/fixtures"))
  assert_true(directory_exists("tests/fixtures/"))
  assert_false(directory_exists("tests/fixtures/no-such-dir"))
  assert_false(directory_exists("tests/fixtures/mule.cfg"))
end
