--[[
  use sqlite3 FTS4 to create a single table, metrics_index with 2 default columns: rowid and content.
  rowid will hold a 64 bit hash, computed using xxhash
  content will hold the metric
  CREATE VIRTUAL TABLE metrics_index USING fts4;
  INSERT into metrics_index(rowid,content) values (8983,'hola.hop'), (83332,'chano.pozo');
--]]


local sqlite3 = require("lsqlite3")
local xxhash = require("xxhash")
require("helpers")

local xh = xxhash.init( 0xA278C5001 )

local function digest(str)
  xh:reset() -- remove leftovers
  xh:update(str)
  local rv = xh:digest()
  xh:reset() -- cleanup
  return rv
end

function indexer(path_)
  local db
  local insert_st,select_st,match_st,dump_st

  local function sqlite_error(label_)
    loge(label_,db:errmsg(),"code",db:errcode())
  end

  local function open_db()
    if not path_ then
      db = sqlite3.open_memory()
    else
      db = sqlite3.open(path_)
    end
    if not db then
      loge("failed opening db",path_ or "in memory",sqlite3.version(),"lib",sqlite3.lversion())
      return false
    end
    logi("opening",path_ or "in memory",sqlite3.version(),"lib",sqlite3.lversion())

    if db:exec("CREATE VIRTUAL TABLE IF NOT EXISTS metrics_index USING fts4")~=sqlite3.OK then
      return sqlite_error("create table failed")
    end

    insert_st = db:prepare("INSERT INTO metrics_index(rowid,content) VALUES (:1,:2)")
    select_st = db:prepare("SELECT rowid FROM metrics_index WHERE rowid=:1")
    dump_st = db:prepare("SELECT rowid,content FROM metrics_index")
    match_st = db:prepare("SELECT content FROM metrics_index WHERE content MATCH :1")

    return true
  end

  local function insert_one(metric)
    local h = digest(metric)
    select_st:bind_values(h)
    for _ in select_st:nrows() do
      --print("found",h,metric)
      return nil -- if we are here, the digest already exists
    end
    --print("not found",h,metric)
    insert_st:bind_values(h,metric)
    insert_st:step()
    insert_st:reset()
    return true
  end

  local function insert(metrics_)
    local count = 0
    for _,m in ipairs(metrics_) do
      if insert_one(m) then
        count = count + 1
      end
    end
    logi("fts insert",count)
  end

  local function search(query_)
    match_st:bind_values(query_)
    for c in match_st:urows() do
      coroutine.yield(c)
    end
  end

  local function dump()
    for id,c in dump_st:urows() do
      coroutine.yield(id,c)
    end
  end

  local function close()
    if db then
      db:close_vm()
      local rv = db:close()
      logi("close",rv)
    end
  end

  if not open_db() then
    return nil
  end

  return {
    insert = insert,
    insert_one = insert_one,
    search = function(query_)
      return coroutine.wrap(
        function()
          search(query_)
        end
      )
    end,
    dump = function()
      return coroutine.wrap(dump)
    end,
    close = close,

  }
end
