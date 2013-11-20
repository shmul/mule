local _,lr = pcall(require,"luarocks.require")
local s,url = pcall(require,"socket.url")
local pp = require "purepack"
local posix_exists,posix = pcall(require,'posix')
local stp_exists,stp = pcall(require,"StackTracePlus")

if not posix_exists or lunit then
  print("disabling posix")
  posix = nil
end

if stp_exists then
  if lunit then
    stp = nil
  else
    debug.traceback = stp.stacktrace
  end
end

-- file/stdout logging
local logfile = nil
local logfile_name = nil
local verbose_logging = false
local logfile_rotation_day = nil

function verbose_log(on_)
  verbose_logging = on_
end

local function rotate_log_file(name)
  local today = os.date("%y%m%d")
  if logfile_rotation_day==today then
    return
  end

  if logfile then
    logfile:flush()
    logfile:close()
    os.rename(logfile_name,logfile_name.."-"..logfile_rotation_day)
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

  local sarg = {os.date("%y%m%d:%H:%M:%S"),level," "}
  table.foreachi({...},function(_,v) table.insert(sarg,tostring(v)) end)
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


local function nop()
end

function tablein(tbl_)
  local current = 0

  local function read()
    current = current + 1
    return tbl_[current]
  end

  return {
    read = read,
         }

end

function ioout_generic(writer_,delim_)
  local function write(...)
    for _,v in ipairs({...}) do
      writer_(tostring(v))
      writer_(delim_)
    end
  end

  return {
    write = write,
         }
end

function ioout(io_,delim_)
  return ioout_generic(function(o_)
                         io_:write(o_)
                       end,delim_)
end

function stdout(delim_)
  return ioout(io.output(),delim_)
end

function ioin_generic(lines_itr_,delim_)
  local read = coroutine.wrap(function()
                                for l in lines_itr_() do
                                  for p in split_helper(l,delim_) do
                                    -- as our arrays write the delimiter after every
                                    -- item, we have to skip the last, empty, one
                                    if #p~=0 then
                                      coroutine.yield(p)
                                    end
                                  end
                                end
                              end)


  return {
    read = read,
         }


end

function ioin(io_,delim_)
  return ioin_generic(io_.lines,delim_)
end

function strout(delim_)
  local str = {}
  local out = ioout_generic(function(o_)
                              table.insert(str,o_)
                            end,delim_ or ",")
  out.get_string = function()
    return table.concat(str,"")
  end
  return out
end


function strin(str_)
  return ioin_generic(function() return string_lines(str_) end,",")
end


function trim(str)
  if not str then return nil end
  local _,_,s = string.find(str,"^%s*(.-)%s*$")
  return s or ""
end

function collectionout(out_,bra_,ckt_)
  local first = true

  return {
    head = function()
      out_.write(bra_)
    end,
    tail = function()
      out_.write(ckt_)

    end,
    elem = function(...)
      if not first then out_.write(",") end
      first = false
      out_.write(...)
    end
         }

end

function shallow_clone_array(array_,max_idx_)
  local cloned = {}
  for i,a in ipairs(array_) do
    if i<=max_idx_ then
      cloned[i] = a
    end
  end
  return cloned
end

function split_helper(str_,delim_)
  return coroutine.wrap(function()
                          local start = 1
                          local t
                          local ds = #delim_
                          local find,sub = string.find,string.sub
                          local yield = coroutine.yield
                          while str_ and start do
                            t = find(str_,delim_,start,true)
                            if t then
                              yield(trim(sub(str_,start,t-1)))
                              start = t+ds
                            else
                              yield(trim(sub(str_,start)))
                              start = nil
                            end
                          end
                        end)
end

function split(str_,delim_)
  local items = {}
  for p in split_helper(str_,delim_) do
    if #p>0 then
      items[#items+1] = p
    end
  end
  return items
end

function string_lines(str_)
  return split_helper(str_,"\n")
end


function remove_comment(line_)
  local hash = string.find(line_,"#",1,true)

  return trim(hash and string.sub(line_,1,hash-1) or line_)
end

function lines_without_comments(lines_iterator)
  return coroutine.wrap(function()
                          for line in lines_iterator do
                            line = remove_comment(line)
                            if #line>0 then coroutine.yield(line) end
                          end
                        end)
end

function n_lines(n,lines_iterator)
  return coroutine.wrap(function()
                          for line in lines_iterator do
                            n = n - 1
                            if n>=0 then coroutine.yield(line) end
                          end
                        end)
end

function concat_arrays(lhs_,rhs_,callback_)
  for _,v in ipairs(rhs_) do
    lhs_[#lhs_+1] = callback_ and callback_(v) or v
  end
  return lhs_
end


function t2s(tbl)
  if not tbl then
    return
  end
  if type(tbl)~='table' then return tostring(tbl) end
  local rep = {}
  for key,val in pairs(tbl) do
    if type(val)=='table' then
      table.insert(rep,string.format('"%s":{%s}',key,t2s(val)))
    else
      table.insert(rep,string.format('"%s":"%s"',key,t2s(val)))
    end
  end

  return table.concat(rep,',')
end

function table_size(tbl_)
  if #tbl_>0 then return #tbl_ end
  local current = 0
  for k,v in pairs(tbl_) do
    current = current + 1
  end

  return current
end


function serialize_table_of_arrays(out_,tbl_,callback_)
  out_.write(table_size(tbl_))
  for key,items in pairs(tbl_) do
    out_.write(key)
    out_.write(#items)
    for _,i in ipairs(items) do
      callback_(out_,i)
    end
  end
end


function deserialize_table_of_arrays(in_,callback_)
  local size = tonumber(in_.read())
  local tbl = {}
  for i=1,size do
    local key = in_.read()
    local num_items = tonumber(in_.read())
    local items = {}
    for j=1,num_items do
      items[#items+1] = callback_(in_)
    end
    tbl[key] = items
  end
  return tbl
end


function with_file(file_,func_,mode_)
  local f = io.open(file_,mode_ or "r")
  if not f then return false end
  local rv = func_(f)
  f:close()
  return rv
end

function file_exists(file_)
  return with_file(file_,function() return true end)
end

function file_size(file_)
  return with_file(file_,
                   function(f)
                     return f:seek("end")
                   end,"rb")
end

-- based on http://lua-users.org/wiki/AlternativeGetOpt
-- with slight modification - non '-' prefixed args are accumulated under the "rest" key
function getopt(arg,options)
  local tab = {}
  tab["rest"] = {}
  local prev_in_options = false

  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
      prev_in_options = false
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          prev_in_options = true
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    else
      if not prev_in_options then
        table.insert(tab["rest"],v)
      end
      prev_in_options = false
    end
  end
  return tab
end

function copy_table(from_,to_)
  if from_ then
    local key,val = next(from_)
    while key and val do
      to_[key] = val
      key,val = next(from_,key)
    end
  end
  return to_
end

local TIME_UNITS = {s=1, m=60, h=3600, d=3600*24, w=3600*24*7, y=3600*24*365}
local TIME_UNITS_SORTED = (function()
                             local array = {}
                             for u,f in pairs(TIME_UNITS) do
                               table.insert(array,{f,u})
                             end
                             table.sort(array,function(a,b)
                                          return a[1]>b[1]
                                              end)
                             return array
                           end)()


local parse_time_unit_cache = {}

function parse_time_unit(str_)
  local secs = nil
  if not str_ then
    return nil
  end
  if not parse_time_unit_cache[str_] then
    string.gsub(str_,"^(%d+)([smhdwy])$",
                function(num,unit)
                  secs = num*TIME_UNITS[unit]
                end)
    parse_time_unit_cache[str_] = secs or tonumber(str_) or 0
  end
  return parse_time_unit_cache[str_]
end

local secs_to_time_unit_cache = {}
function secs_to_time_unit(secs_)
  if secs_to_time_unit_cache[secs_] then
    return secs_to_time_unit_cache[secs_]
  end
  local fmod = math.fmod
  for _,v in pairs(TIME_UNITS_SORTED) do
    if secs_>=v[1] and fmod(secs_,v[1])==0 then
      local rv = (secs_/v[1])..v[2]
      secs_to_time_unit_cache[secs_] = rv
      return rv
    end
  end

  return nil
end


function max_timestamp(size_,get_slot_)
  local max = nil
  local idx = 0
  for i=1,size_ do
    local current = get_slot_(i)
    if not max or current._timestamp>max._timestamp then
      max = current
      idx = i
    end
  end
  return idx
end

function is_prefix(metric_,prefix_)
  return prefix_=="*" or string.find(metric_,prefix_,1,true)==1
end

function parse_time_pair(str_)
  local step,period = string.match(str_,"^(%w+):(%w+)$")
  return parse_time_unit(step),parse_time_unit(period)
end

function normalize_timestamp(timestamp_,step_,period_)
  return math.floor(timestamp_/step_)*step_
end

function calculate_idx(timestamp_,step_,period_)
  local idx = math.floor((timestamp_ % period_) / step_)
  -- adjust the timestamp so it'll be at the beginning of the step
  return idx,normalize_timestamp(timestamp_,step_,period_)
end

function to_timestamp_helper(expr_,now_,latest_)
  local interpolated = string.gsub(expr_,"(%l+)",{now=now_, latest=latest_})
  interpolated = string.gsub(interpolated,"(%w+)",parse_time_unit)
  return string.match(interpolated,"^[%s%d%-%+]+$") and loadstring("return "..interpolated)() or nil
end

function to_timestamp(expr_,now_,latest_)
  local from,to = string.match(expr_,"(.+)%.%.(.+)")
  if not from then
    return to_timestamp_helper(expr_,now_,latest_)
  end
  from = to_timestamp_helper(from,now_,latest_)
  to = to_timestamp_helper(to,now_,latest_)
  return {from,to}
end


function parse_input_line(line_)
  local items = nil
  if string.sub(line_,1,1)=='.' then
    -- command
    items = split(line_,' ')
    items[1] = string.sub(items[1],2)
    return items,"command"
  end
  -- metrics
  items = split(line_,' ')
  return items
end

function metric_hierarchy(metric_)
  return coroutine.wrap(
    function()
      local format = string.format
      local current = ""
      for i,p in ipairs(split(metric_,'.')) do
        current = i==1 and p or format("%s.%s",current,p)
        coroutine.yield(current)
      end
    end)
end

TRUTH = { [true]=true,["true"]=true, yes=true, on=true, [1]=true }
function is_true(str_)
  return str_ and TRUTH[str_]
end

function qs_params(raw_qs_)
  local match = string.match
  local params = {}
  for _,p in ipairs(split(raw_qs_ or "","&")) do
    local k,v = match(p,"([^=]+)=(.+)$")
    if k then
      params[k] = url.unescape(v) or ""
    end
  end
  return params
end

function keys(table_)
  local ks = {}
  local insert = table.insert

  for k,_ in pairs(table_) do
    insert(ks,k)
  end

  return ks
end

function split_name(name_)
  local metric,step,period = string.match(name_,"^(.+);(%w+):(%w+)$")
  return metric,step and parse_time_unit(step),period and parse_time_unit(period)
end


function get_slot(data_,idx_,offset_)
  -- idx_ is zero based
  local fromb,size = pp.from_binary,pp.PNS
  if offset_ then
    local i = 1+(idx_*size*3)+offset_*size
    return fromb(data_,i)
  end
  local i = 1+(idx_*size*3)
  return fromb(data_,i),fromb(data_,i+size),fromb(data_,i+size*2)
end


function set_slot(data_,idx_,offset_,a,b,c)
  -- idx_ is zero based
  local tob,sub = pp.to_binary,string.sub
  local size = pp.PNS
  if offset_ then
    local i = 1+(idx_*size*3)+offset_*size
    return sub(data_,1,i-1),tob(a),sub(data_,i+size)
  end
  local i = 1+(idx_*size*3)
  return sub(data_,1,i-1),tob(a),tob(b),tob(c),sub(data_,i+size*3)
end

function printf(format_,...)
  print(string.format(format_,...))
end

function hex(s)
 return string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
end

-- the whole purpose of this is to enable tests to override it.
function time_now()
  return os.time()
end


-- based on http://en.wikibooks.org/wiki/Algorithm_implementation/Sorting/Insertion_sort#JavaScript


function insertion_sort(array_)
  for i,v in ipairs(array_) do
    local j = i-1
    while j>0 and array_[j]>v do
      array_[j+1] = array_[j]
      j = j - 1
    end
    array_[j+1] = v
  end
  return array_
end

function bounded_by_level(string_,prefix_,level_)
  local count = 0
  local s = #prefix_-1
  local find = string.find
  repeat
    s = find(string_,".",s+1,true)
    if s then
      count = count + 1
    end
  until not s or count>level_
  return count<=level_
end

-- from http://stackoverflow.com/questions/132397/get-back-the-output-of-os-execute-in-lua
function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

function hex(s)
  return string.gsub(s,"(.)",function (x) return string.format("%02X",string.byte(x)) end)
end

function adler32(str_)
  local a = 1
  local b = 0
  for i=1,#str_ do
    a = math.fmod(a + string.byte(str_,i,i),65521)
    b = math.fmod(b + a,65521)
  end
  return b*65536 + a
end

function fork_and_exit(callback_)
  if not posix then
    return callback_()
  end

  local child = posix.fork()
  if child~=0 then
    logi("fork (parent)",posix.getpid('pid'),child)
    return
  end
  logi("fork (child)",posix.getpid('pid'))
  callback_()
  logi("exiting",posix.getpid('pid'))
  os.exit()
end

function noblock_wait_for_children()
  if posix then
    posix.wait(-1,posix.WNOHANG)
  end
end


function update_rank_helper(rank_timestamp_,rank_,timestamp_,value_,step_)
  -- it is assumed both timestamps are already normalized
  if rank_timestamp_==timestamp_ or rank_timestamp_==0 then
    return timestamp_,rank_+value_,true
  end

  -- we need to multiply the current rank
  return timestamp_,value_+rank_/(2^((timestamp_-rank_timestamp_)/step_)),false
end

function pcall_wrapper(callback_,...)
  local params = ...
  return xpcall(function() return callback_(params) end ,stp and stp.stacktrace or nil)
end
