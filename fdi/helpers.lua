-- file/stdout logging
local logfile = nil
local logfile_name = nil
local verbose_logging = false
local logfile_rotation_day = nil
local rotation_counter = 0

function verbose_log(on_)
  verbose_logging = on_
end

local function rotate_log_file(name)
  rotation_counter = rotation_counter + 1
  if rotation_counter%10~=1 then
    return
  end

  local today = os.date("%y%m%d")
  if logfile_rotation_day==today then
    return
  end

  if logfile then
    local rotated_file_name = logfile_name.."-"..logfile_rotation_day
    logfile:flush()
    logfile:close()
    if not file_exists(rotated_file_name) then
      os.rename(logfile_name,rotated_file_name)
    end
  end

  logfile_rotation_day = today
  name = name or logfile_name
  if not name then return nil end

  local f = io.open(name,"a")
  if not f then
    io.stderr:write(name,"\n")
    return nil, string.format("can't open `%s' for writing",name)
  end
  f:setvbuf ("line")
  logfile = f
  logfile_name = name
end

function log_file(path_)
  local name = string.find(path_,"%.log$") and path_ or string.format("%s.log",path_)
  rotate_log_file(name)
end

local function flog(level,...)
  rotate_log_file()
  local pid = posix and posix.getpid('pid') or "-"
  local sarg = {pid,os.date("%y%m%d:%H:%M:%S"),level," "}
  for _,v in ipairs({...}) do
    table.insert(sarg,tostring(v))
  end
  local msg = table.concat(sarg," ")
  if verbose_logging then
    io.stderr:write(msg,"\n")
  end
  if logfile then
    logfile:write(msg,"\n")
  end
  return true
end

function close_log_file()
  if logfile then
    logfile:close()
    logfile = nil
  end
end


function logd(...)
  return ((logfile or verbose_logging) and flog("d",...))
end

function logi(...)
  return ((logfile or verbose_logging) and flog("i",...))
end

function logw(...)
  return ((logfile or verbose_logging) and flog("w",...))
end

function loge(...)
  return ((logfile or verbose_logging) and flog("e",...))
end

function logf(...)
  return ((logfile or verbose_logging) and flog("f",...))
end
