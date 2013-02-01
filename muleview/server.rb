require 'sinatra'
set :root, File.dirname(__FILE__)
set :port, 8082
set :public_folder do
  root
end

get "/" do
  call env.merge('PATH_INFO' => '/muleview.html')
end
