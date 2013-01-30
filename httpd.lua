require "helpers"

local lr = pcall(require,"luarocks.require")
local cp = pcall(require,"copas")
local s,url = pcall(require,"socket.url")

if not lr and cp then
  loge("unable to find luarocks or copas")
  return nil
end

require "mulelib"

local function read_chunks(socket_)
  local chunks = {}
  while true do
    local data = socket_:receive("*l")
    if not data then
      return table.concat(chunks,"")
    end
    local size = tonumber(string.format("0x%s",data))
    if size>0 then
      data = socket_:receive(size)
      table.insert(chunks,data)
    end
    if data then socket_:receive(2) end
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
	  local content
	  if content_len and content_len>0 then
		content = socket_:receive(content_len)
		if content and #content<content_len then
		  logw("insufficient content received",#content,content_len)
		end
      elseif req["Transfer-Encoding"]=="chunked" then
        logd("chunked encoding")
        content = read_chunks(socket_)
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
  table.insert(response,string.format("Content-Length: %d",body_ and #body_ or 0))
  table.insert(response,"\r\n") -- for the trailing \r\n
  return table.concat(response,"\r\n")
end

local function standard_response(status_,content_)
  return build_response(string.format("HTTP/1.1 %s",status_),{{"Connection","close"}},content_)
end

local function generic_get_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb~="GET" then
    logw("Only GET can be used")
    return
  end
  logd("calling",handler_)
  return mule_[handler_](resource_,qs_params_)
end

local function graph_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="GET" then
    logd("calling",handler_)
    return mule_.graph(resource_,qs_params_)
  elseif req_.verb=="POST" then
    logd("calling",handler_)
    return mule_.process(lines_without_comments(string_lines(content_)))
  end
end

local function config_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="POST" then
    logd("calling",handler_)
    return mule_.configure(lines_without_comments(string_lines(content_)))
  end
end

local function crud_handler(mule_,handler_,req_,resource_,qs_params_,content_)
  if req_.verb=="PUT" then
    return mule_.alert_set(resource_,qs_params(content_))
  elseif req_.verb=="DELETE" then
    return mule_.alert_remove(resource_)
  elseif req_.verb=="GET" then
    return mule_.alerts(resource_)
  end
end

local function nop_handler()
end

local handlers = { key = generic_get_handler,
                   graph = graph_handler,
                   piechart = generic_get_handler,
                   latest = generic_get_handler,
                   slot = generic_get_handler,
                   update = graph_handler,
                   config = config_handler,
                   stop = nop_handler,
                   alert = crud_handler,
}


local function send_response(send_,req_,content_,with_mule_,stop_cond_)

  if not req_ then
	return send_(standard_response("400 Bad Request"))
  end

  local url_no_qs = string.match(req_.url,"^([^%?]+)")
  local raw_qs = string.match(req_.url,"%?(.+)$")
  local qs = qs_params(raw_qs)
  local segments = split(url_no_qs,"/")
  local handler_name = segments[1]
  local handler = handlers[handler_name]

  if not handler then
	return send_("404 Not Found")
  end

  local rv = with_mule_(
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

  if handler_name=="stop" then
    logw("stopping, using: ",qs_params.token)
    stop_cond_(token)
  end

  if not rv or #rv==0 then
    return send_(standard_response("204 No Content"))
  end

  if qs.jsonp then
    rv = string.format("%s(%s)",qs.jsonp,rv)
  end
  return send_(standard_response("200 OK",rv),rv)
end


function http_loop(address_port_,with_mule_,stop_cond_)
  local address,port = string.match(address_port_,"(%S-):(%d+)")
  copas.addserver(socket.bind(address,port),
				  function(socket_)
					--socket_:setoption ("linger", {on=true,timeout=7})
					socket_:settimeout(0)
					--socket_:setoption ("tcp-nodelay", true)
					local wrapped_socket = copas.wrap(socket_)
					local req,content = read_request(wrapped_socket)

                    local function send(headers_,body_)
                      local s,err = socket_:send(headers_)
                      if body_ and #body_>0 then
                        s,err = socket_:send(body_)
                      end
                      logi("send_response",s,err)
                      return s,err
                    end


					send_response(send,req,content,with_mule_,stop_cond_)
				  end)
  while not stop_cond_() do
	copas.step()
  end
end
