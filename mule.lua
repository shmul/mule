require "helpers"
require "mulelib"
require "tc_store"
local c = require "column_db"
require "httpd"

pcall(require, "profiler")

local function strip_slash(path_)
  return string.match(path_,"^(.-)/?$")
end

local function guess_db(db_path_,readonly_)
  logd("guess_db",db_path_)
  -- strip a trailing / if it exists
  db_path_ = strip_slash(db_path_)
  if string.find(db_path_,"_cdb$") then
    return c.column_db(db_path_,readonly_)
  elseif string.find(db_path_,cabinet.suffix.."$") then
    return cabinet_db(db_path_,readonly_)
  end
  loge("can't guess db",db_path_)
  return nil
end

local function with_mule(db_path_,readonly_,callback_)
  local db = guess_db(db_path_,readonly_)
  if not db then
    return
  end
  local m = mule(db)
  logi("loading",db_path_,readonly_ and "read" or "write")
  m.load()
  local success,rv = pcall(callback_,m)

  if not success then
    loge("error",rv)
    db.close()
    return nil
  end
  if not readonly_ then
    logi("saving",db_path_)
    m.save()
  end
  logi("closing",db_path_)
  db.close()
  m = nil
  return rv
end

local function backup(db_path_)
  function helper()
    local db_path = strip_slash(db_path_)
    local bak = string.format("%s.bak.%s",db_path,os.date("%y%m%d-%H%M%S"))
    os.execute(string.format("cp -r %s %s",db_path_,bak))
    logi("backed up to",bak)
    return bak
  end

  return helper
end

local function fatal(msg_,out_)
  logf(msg_)
  out_.write(msg_)
end

local function usage()
  return [[
        -h (help) -v (verbose) -y profile -l <log-path> -d <db-path> [-c <cfg-file> (configure)] [-r (create)] [-f (force)] [-n <line>] [-t <address:port> (http daemon)] [-x (httpd stoppable)] files....

      If -c is given the database is (re)created but if it exists, -f is required to prevent accidental overwrite. Otherwise load is performed.
      Files are processed in order
  ]]

end

function main(opts,out_)
  if opts["h"] then
    out_.write(usage())
    return true
  end


  if opts["v"] then
    verbose_log(true)
  end

  if opts.y then
    logd("starting profiler")
    profiler.start("profiler.out")
  end

  if opts["l"] then
    log_file(opts["l"])
  end

  if not opts["d"] then
    fatal("no database given. exiting",out_)
    return false
  end

  local function writable_mule(callback_)
    return with_mule(opts["d"],false,function(m) return callback_(m) end)
  end

  local function readonly_mule(callback_)
    return with_mule(opts["d"],true,function(m) return callback_(m) end)
  end

  local db_exists = file_exists(opts["d"])

  if opts["r"] and db_exists and not opts["f"] then
    fatal("database exists and may be overwriten. use -f to force re-creation. exiting",out_)
    return false
  end

  if not opts["c"] and not db_exists then
    fatal("database does not exist and no configuration is provided. existing",out_)
    return false
  end


  if opts["r"] then
    logi("creating",opts["d"],"using configuration",opts["c"])
    local db = guess_db(opts["d"],false)
    if not db then
      return
    end
    db:close()
  end


  if opts["c"] then
    logi("configure",opts["c"])
    local rv = writable_mule(function(m)
                               with_file(opts["c"],
                                         function(f)
                                           m.configure(f:lines())
                                         end)
                             end)
    if not rv then
      loge("configure failed.")
      if not file_exists(opts["c"]) then
        loge("file does not exists ",opts["c"])
      end
      return
    end
  end

  if opts["t"] then
    logi("http daemon",opts["t"])
    local stopped = false
    local httpd_can_be_stopped = opts["x"]
    http_loop(opts["t"],writable_mule,
              backup(opts["d"]),
              function(token_)
                -- this is confusing: when the function is called with param we match
                -- it against the stop shared secret
                -- when it is called without a param we simply return the flag
                -- BUT we check that the stop functionality is supported at all
                stopped = stopped or httpd_can_be_stopped and token_==httpd_can_be_stopped
                return stopped
              end)
  end

  if opts["n"] then
    local rv = writable_mule(function(m)
                               return m.process(opts["n"])
                             end)
    out_.write(rv)
  end

  if opts["rest"] then
    writable_mule(function(m)
                    for _,f in ipairs(opts["rest"]) do
                      logi("processing",f)
                      local rv = m.process(f)
                      out_.write(rv)
                    end
                  end)
  end

  if opts.y then
    logd("stopping profiler")
    profiler.stop()
  end

  return true
end


if not lunit then
  opts = getopt(arg,"ldcnmtx")
  local rv = main(opts,stdout("\n"))
  logd("done")
  os.exit(rv and 0 or -1)
end
