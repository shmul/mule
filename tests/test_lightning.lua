local l = require "lightning_mdb"
require "tests.strict"
require "helpers"

module( "lightning_mdb", lunit.testcase,package.seeall )

local function lightning_mdb_factory(name_)
  local dir = name_.."_mdb"
  os.execute("rm -rf "..dir)
  os.execute("mkdir -p "..dir)
  return l.lightning_mdb(dir)
end

function test_meta()
  local db = lightning_mdb_factory("./tests/temp/l_meta")
  db.put("metadata=hello","cruel world")
  assert_equal("cruel world",db.get("metadata=hello"))
  assert_nil(db.get("hello"))
end


verbose_log(true)