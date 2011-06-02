require "helpers"

local lr = pcall(require,"luarocks.require")
local cp = pcall(require,"copas")
local s,url = pcall(require,"socket.url")

if not lr and cp then
  loge("unable to find luarocks or copas")
  return nil
end

require "mulelib"

local function read_request(socket_)
  local req = {}
  while true do
	local data = socket_:receive("*l")
	if not data or #data==0 then 
	  local content_len = tonumber(req["Content-Length"])
	  local content
	  if content_len then
		content = socket_:receive(content_len)
		if content and #content<content_len then
		  logw("insufficient content received",#content,content_len)
		end
	  end
	  return req,content
	end
	if not req.verb then
	  req.verb,req.url,req.protocol = string.match(data,"(%S+) (%S+) (%S+)$")
	else
	  local header_name,header_value = string.match(data,"([^:]+): (.-)$")
	  if header_name and header_value then
		req[header_name] = header_value
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

local handlers = { keys=true, graph=true, latest=true, slot=true }

local function send_response(socket_,req_,with_mule_)
  if not req_ then
	socket_:send(standard_response("400 Bad Request"))
	return
  end

  local headers,body
  local segments = split(req_.url,"/")
  local resource = segments[1]
  table.remove(segments,1)
  local decoded_segments = {}
  for _,s in ipairs(segments) do
	local unescaped,_ = url.unescape(s)
	table.insert(decoded_segments,unescaped)
  end
  local path = table.concat(decoded_segments,"/")
  local path_no_qs = string.match(path,"^([^&%?]+)")
  local qs = string.match(path,"%?(.+)$")

  if handlers[resource] then
	local rv = with_mule_(function(mule_)
							return mule_.process({string.format(".%s %s %s",resource,path_no_qs or "*",qs or "")})
						  end)
	if rv and #rv>0 then
	  headers = standard_response("200 OK",rv)
	  body = rv
	else
	  headers = standard_response("204 No Content")
	end
  else
	headers = standard_response("404 Not Found")
  end

  local s,err = socket_:send(headers)
  if body and #body>0 then
	s,err = socket_:send(body)
  end
  logi("send_response",s,err)
  
end


local function handle_request(socket_,with_mule_)
  local req = read_request(socket_)
  send_response(socket_,req,with_mule_)
end

function http_loop(host_port_,with_mule_,stop_cond_)
  local host,port = string.match(host_port_,"(%S-):(%d+)")
  copas.addserver(socket.bind(host,port),
				  function(socket_)
					--socket_:setoption ("linger", {on=true,timeout=7})
					socket_:settimeout(0)
					--socket_:setoption ("tcp-nodelay", true)
					return handle_request(copas.wrap(socket_),with_mule_)
				  end)
  while not stop_cond_() do
	copas.step()
  end
end


