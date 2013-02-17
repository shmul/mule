require 'sinatra'
require 'json'

set :root, File.dirname(__FILE__)
set :port, 8082
set :public_folder do
  root
end

get "/" do
  call env.merge('PATH_INFO' => '/index.html')

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

# get %r[/mule/graph.*] do
#   content_type :js
#   %Q[{"version": 3,
# "data": {"wine.pinotage.south_africa;1d:3y": #{generate_series}
# }
# }
# ]
# end

# get %r[/mule/key.*] do
#   content_type :js
#   %q[{"version": 3,
# "data": ["wine.pinotage.south_africa;1d:3y","wine.pinotage.south_africa;1h:30d","wine.pinotage.south_africa;5m:2d","wine.pinotage.brazil;1d:3y","wine.pinotage.brazil;1h:30d","wine.pinotage.brazil;5m:2d","wine.pinotage.canada;1d:3y","wine.pinotage.canada;1h:30d","wine.pinotage.canada;5m:2d","wine.pinotage.us;1d:3y","wine.pinotage.us;1h:30d","wine.pinotage.us;5m:2d","wine.pinotage;1d:3y","wine.pinotage;1h:30d","wine.pinotage;5m:2d"]
# }
# ]
# end

# def generate_series
#   ans = []
#   100.times do |i|
#     ans << [rand(0..1000), 0, (Time.now + 10*i).to_i]
#   end
#   ans
# end
