require "helpers"


local lr = require "luarocks.require"
local ltn12 = require "ltn12"
local url = require "socket.url"
local copas = require "copas"

local status_codes = {
  [200] = "200 OK",
  [201] = "201 Created",
  [204] = "204 No Content",
  [304] = "304 Not Modified",
  [400] = "400 Bad Request",
  [404] = "404 Not Found",
  [405] = "405 Method Not Allowed"
}


require "mulelib"

local function read_chunks(socket_)
  local sink,chunks = ltn12.sink.table()
  while true do
    local data = socket_:receive("*l")
    if not data then
      return table.concat(chunks,"")
    end
    local size = tonumber(string.format("0x%s",data))
    if size>0 then
      ltn12.pump.all(socket.source("by-length",socket_,size),sink)
    end
    socket_:receive(2)
    if size==0 then
      return table.concat(chunks,"")
    end
  end
end

local function read_request(socket_)
  local req = {}

  while true do
    local data = socket_:receive("*l")
    if not data or #data==0 then
      local content_len = tonumber(req["Content-Length"])
      local sink,content = ltn12.sink.table()
      if content_len and content_len>0 then
        local s,err = ltn12.pump.all(socket.source("by-length",socket_,content_len),sink)
        content = s and table.concat(content)
        if not content or #content<content_len then
          logw("insufficient content received",content and #content or "nil",
               content and content_len or 0)
        end
      elseif req["Transfer-Encoding"]=="chunked" then
        logd("chunked encoding")
        content = read_chunks(socket_)
      end
      -- we may be left with an _empty_ table, in which case we'll concat it
      if type(content)=="table" then
        content = table.concat(content)
      end
      return req,content
    end

    if not req.verb then
      req.verb,req.url,req.protocol = string.match(data,"(%S+) (%S+) (%S+)$")
    else
      local header_name,header_value = string.match(data,"([^:]+): (.-)$")
      if header_name and header_value then
        req[header_name] = header_value
        if header_name=="Expect" and header_value=="100-continue" and
          (req.verb=="POST" or req.verb=="PUT") and req.protocol~="HTTP/1.0" then
          socket_:send("HTTP/1.1 100 Continue\r\n\r\n")
        end
      else
        return req
      end
    end
  end
end

local function build_response(status_,headers_,body_)
  local response = {status_}
  concat_arrays(response,headers_,function(header_)
									return string.format("%s: %s",header_[1],header_[2])
                                  end)
  if body_ then -- might be a string or size
    local length = type(body_)=="string" and #body_ or body_
    table.insert(response,string.format("Content-Length: %d",length))
  end
  table.insert(response,"\r\n") -- for the trailing \r\n
  return table.concat(response,"\r\n")
end

local CORS = {{"Access-Control-Allow-Origin","*"},{"Access-Control-Allow-Headers","Origin, X-Requested-With, Content-Type, Accept"}}
local CONTENT_TYPE_JSON = {"Content-Type","application/json"}

local function standard_response(status_,content_,extra_headers_)
  local headers = {{"Connection","keep-alive"}}
  if extra_headers_ then
    concat_arrays(headers,extra_headers_)
  end
  return build_response(string.format("HTTP/1.1 %s",status_codes[status_]),
                        headers,content_)
end

local function generic_get_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb~="GET" then
    logw("Only GET can be used")
    return
  end
  logd("GET: calling",handler_)
  return function() return mule_[handler_](resource_,qs_params_) end
end

local function graph_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="GET" then
    return generic_get_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  elseif req_.verb=="POST" then
    logd("POST: calling",handler_,#content_)
    return mule_.process(lines_without_comments(string_lines(content_)),true)
  elseif req_.verb=="DELETE" then
    logd("DELETE: calling",handler_)
    return mule_.reset(resource_,qs_params_)
  else
    logw("Only GET/POST can be used")
    return 405
  end
end

local function gc_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="DELETE" then
    logd("DELETE: calling",handler_)
    return mule_.gc(resource_,qs_params_)
  else
    logw("Only DELETE can be used")
    return 405
  end
end


local function config_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="POST" then
    logd("calling",handler_)
    return mule_.configure(lines_without_comments(string_lines(content_))) and 200 or 400
  elseif req_.verb=="DELETE" then
    logd("DELETE: calling",handler_)
    return mule_.factories_out(resource_,qs_params_)
  elseif req_.verb=="GET" then
    logd("calling",handler_)
    return mule_.export_configuration()
  end
  return 405
end

local function alert_crud_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="PUT" then
    local rv = mule_.alert_set(resource_,qs_params(content_))
    if rv=="" then
      return 201,{{"Location","./"..resource_}}
    end
    return 400
  elseif req_.verb=="DELETE" then
    return mule_.alert_remove(resource_)
  elseif req_.verb=="GET" then
    return mule_.alert(resource_)
  end
  return 405
end

local function kvs_crud_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="PUT" or req_.verb=="POST" then
    mule_.kvs_put(resource_,content_)
    return 201
  elseif req_.verb=="DELETE" then
    return mule_.kvs_out(resource_)
  elseif req_.verb=="GET" then
    return function() return mule_.kvs_get(resource_) end
  end
  return 405
end

local function nop_handler()
end

local handlers = { key = generic_get_handler,
                   graph = graph_handler,
                   gc = gc_handler,
                   latest = generic_get_handler,
                   slot = generic_get_handler,
                   update = graph_handler,
                   config = config_handler,
                   stop = nop_handler,
                   alert = alert_crud_handler,
                   kvs = kvs_crud_handler,
                   backup = nop_handler
}


function send_response(send_,send_file_,req_,content_,with_mule_,
                       backup_callback_,stop_cond_,can_fork_)

  if not req_ or not req_.url or not req_.verb then
    return send_(standard_response(400))
  end

  local url_no_qs = string.match(req_.url,"^([^%?]+)")
  local raw_qs = string.match(req_.url,"%?(.+)$")
  local qs = qs_params(raw_qs)
  local segments = split(url_no_qs,"/")
  local handler_name = segments[1]
  local handler = handlers[handler_name]
  local rv

  if not handler then
    if #segments == 0 then url_no_qs = "/index.html" end -- Support a default landing page
    return send_file_(url_no_qs,req_["If-None-Match"])
  end
  if req_.verb=="OPTIONS" then
    return send_(standard_response(200,nil,CORS))
  end
  logi("send_response - handling",req_.url)
  local handler_result,extra_headers = with_mule_(
    function(mule_)
      table.remove(segments,1)
      local decoded_segments = {}
      for _,s in ipairs(segments) do
        local unescaped,_ = url.unescape(s)
        table.insert(decoded_segments,unescaped)
      end

      return handler(mule_,handler_name,req_,table.concat(decoded_segments,"/"),
                     qs,content_)
    end)

  local function response_continuation(rv,blocking_,extra_headers_)
    if handler_name=="stop" then
      logw("stopping, using: ",qs.token)
      stop_cond_(qs.token)
    elseif handler_name=="backup" then
      if req_.verb=="POST" then
        local path = backup_callback_()
        rv = path and string.format("{'path':'%s'}",path) or "{}"
      else
        logw("Only POST can be used")
        rv = nil
      end
    end

    if not rv or (type(rv)=="string" and #rv==0) then
      return send_(standard_response(204,nil,extra_headers_),nil,blocking_)
    elseif type(rv)=="number" then
      return send_(standard_response(rv,nil,extra_headers_),nil,blocking_)
    end

    local headers = extra_headers_ or {}
    table.insert(headers,CONTENT_TYPE_JSON)
    return send_(standard_response(200,rv,headers),rv,blocking_)
  end

  if type(handler_result)~="function" then
    response_continuation(handler_result,false,extra_headers)
    return
  end

  if can_fork_ then
    fork_and_exit(function()
        response_continuation(handler_result(),true)
    end)
    return
  end

  response_continuation(handler_result(),false)
end


function http_loop(address_port_,with_mule_,backup_callback_,incoming_queue_callback_,stop_cond_,root_,can_fork_)
  local address,port = string.match(address_port_,"(%S-):(%d+)")
  local sr = ltn12.source

  local function send(socket_)
    return
      function(headers_,body_,blocking_)
        logd("about to send",headers_ and #headers_ or 0,body_ and #body_ or 0)
        if not blocking_ then
          local s,err = ltn12.pump.all(
            sr.cat(sr.string(headers_),
                   sr.string(body_)),
            socket.sink("close-when-done",socket_))
          logi("send, non blocking",s,err)
        else
          local all_data = headers_..(body_ or "")
          local s,err = copas.send(socket_,all_data)
          socket.sink("close-when-done",socket_)
          logi("send, blocking",s,err)
        end
        return s,err
      end
  end


  local function send_file(socket_)
    return
      function(path_,if_none_match)
        logd("send_file",path_)
        local file = root_ and not string.find(path_,"^/[/%.]+") and string.format("%s/%s",root_,path_)
        if not file or not file_exists(file) then
          return ltn12.pump.all(sr.string(standard_response(404)),
                                socket.sink("close-when-done",socket_))
        end

        local etag = adler32(os.capture('ls -l '..file))
        if if_none_match and tonumber(if_none_match)==etag then
          return ltn12.pump.all(
            sr.string(standard_response(304)),
            socket.sink("close-when-done",socket_))
        end

        return ltn12.pump.all(
          sr.cat(
            sr.string(standard_response(200,file_size(file),{{"ETag",etag}})),
            sr.file(io.open(file,"rb"))),
          socket.sink("close-when-done",socket_))
      end
  end

  copas.addserver(socket.bind(address,port),
                  function(socket_)
                    --socket_:setoption ("linger", {on=true,timeout=7})
                    socket_:settimeout(0)
                    --socket_:setoption ("tcp-nodelay", true)
                    logi("accepting connection",socket_:getpeername(),socket_:getsockname())
                    local skt = copas.wrap(socket_)
                    -- copas wrapping doesn't provide close, but ltn12 needs it.
                    -- we add it and do nothing, letting copas do its thing
                    -- or if it doesn't work we can call 'return socket_:close'
                    skt.close = function() end
                    local req,content = read_request(skt)

                    send_response(send(skt),send_file(skt),
                                  req,content,with_mule_,backup_callback_,stop_cond_,can_fork_)
                  end)
  local i = 0

  local function step()
    copas.step(0)
  end

  while not stop_cond_() do
    step()
    if can_fork_ then
      noblock_wait_for_children()
    end
    with_mule_(function(mule_)
                 mule_.flush_cache(UPDATE_AMOUNT,step)
                 incoming_queue_callback_(mule_,NUM_INCOMING_FILES)
               end)
    i = i + 1
  end
end

--verbose_log(true)
