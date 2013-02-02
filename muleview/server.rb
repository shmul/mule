require 'sinatra'
require 'json'

set :root, File.dirname(__FILE__)
set :port, 8082
set :public_folder do
  root
end

get "/" do
  call env.merge('PATH_INFO' => '/muleview.html')

end

get %r[/mule/(.*)] do |cmd|
  content_type :js
  puts "command: '#{cmd.to_s}'"
  full = "#{cmd}?#{request.query_string}"
  puts "full: '#{full}"
  curl = "curl http://localhost:3000/#{full}"
  puts('server.rb\\ 21: curl:', curl)
  ans = %x[#{curl}]
  puts "ans: '#{ans}'"
  ans
end
