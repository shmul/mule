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

get "/mule/keys" do
  content_type :js
  data = {
    "version" => 3,
    "data" => [
             "wine.pinotage.south_africa;1d:3y",
             "wine.pinotage.south_africa;1h:30d",
             "wine.pinotage.south_africa;5m:2d",
             "wine.pinotage.brazil;1d:3y",
             "wine.pinotage.brazil;1h:30d",
             "wine.pinotage.brazil;5m:2d",
             "wine.pinotage.canada;1d:3y",
             "wine.pinotage.canada;1h:30d",
             "wine.pinotage.canada;5m:2d",
             "wine.pinotage.us;1d:3y",
             "wine.pinotage.us;1h:30d",
             "wine.pinotage.us;5m:2d",
             "wine.pinotage;1d:3y",
             "wine.pinotage;1h:30d",
             "wine.pinotage;5m:2d",
             "beer.stout.oatmeal",
             "beer.stout.russian_imperial",
             "beer.ale"
            ]
  }
  "callback(#{data.to_json})"
end
