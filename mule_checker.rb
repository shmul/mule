#!/usr/bin/env ruby
#
# Nagios check for data points stored in mule server
# Compares last value with the avg of last 5 timestamps values

require 'rubygems'
require 'json' 
require 'net/http'
require 'pp'
require 'uri' # as url
require 'trollop' # command line pharser

EXIT_OK = 0
EXIT_WARNING = 1
EXIT_CRITICAL = 2
EXIT_UNKNOWN = 3

TIMEFRAME_SECONDS = {
  "5m" => 300,
  "1h" => 3600,
  "1d" => 86400
}

# Example response body:
#
# mule_graph({"version": 2,
#            "data": {
#  "event.full_installer_request;5m:2d":[[127,39,1303476300,],....,]
#}
#})

def extract_json_string_for_mule_response_body(body)
  json_string = body && body.strip[/\Amule_[a-z]+\((.*)\)\Z/m,1]
  json_string ? json_string.gsub(/,\]/,"]") : nil
end

def sort_piechart(host,port,series,timeframe)
  # sort piechart res ( for the last two timeframes )
  piechart_timeframe = (timeframe[0].chr.to_i*2).to_s + timeframe[1].chr
  piechart_req = "http://#{host}:#{port}/piechart/#{series};#{timeframe}?l-#{piechart_timeframe}"
  piechart_output = %x{curl -s "#{piechart_req}"}
  piechart_json_str = extract_json_string_for_mule_response_body(piechart_output)
  piechart_str = piechart_json_str ? JSON.parse(piechart_json_str): nil
  piechart_data = piechart_str['data']
  slices = piechart_data.map { |series,v| [(v && v[0] && v[0][0]) || -999, series] }
  slices.sort.reverse.select { |sum,series| sum > 0 }.each do |sum,series|
    puts "#{sum} - #{series}"
  end

end

c = Trollop::options do
  opt :host, "Mule server host", :type => String, :required => true
  opt :port, "Mule server port", :type => String, :required => true
  opt :series, "Mule series name", :type => String, :required => true
  opt :timeframe, "Mule timeframe", :type => String, :required => true
  opt :crit, "Critical threshold", :type => Integer
  opt :low_crit, "Low critical threshold", :type => Integer
  opt :warn, "Warning threshold", :type => Integer
  opt :low_warn, "Low warning threshold", :type => Integer
  opt :crit_precent, "Critical threshold precent", :type => Integer
  opt :low_crit_precent, "Low critical threshold precent", :type => Integer
  opt :warn_precent, "Warning threshold precent", :type => Integer
  opt :low_warn_precent, "Low warning threshold precent", :type => Integer
  opt :full, "use full queries", :type => :flag, :default => false
end

fail "Please provide a critical threshold" unless c[:crit_precent]

now = Time.now.utc.to_i
precision = c[:timeframe].split(":").first

value = nil
begin
  # Example: curl "http://dime:8980/latest/event.full_installer_request;5m:2d"
  # http://dime:8980/graph/event.full_installer_request.zions;5m:2d?latest,latest-5m,latest..latest-1h
  precision_in_secs = TIMEFRAME_SECONDS[precision]
  # get last relevant timestamp
  prev_timestamp = "http://#{c[:host]}:#{c[:port]}/" + (c[:full] ?
      "graph/#{c[:series]};#{c[:timeframe]}" :
      "graph/#{c[:series]};#{c[:timeframe]}?latest-#{precision_in_secs}s")
  # get previous 5 timestamps
  timestamps = "http://#{c[:host]}:#{c[:port]}/" + (c[:full] ?
      "graph/#{c[:series]};#{c[:timeframe]}" :
      "graph/#{c[:series]};#{c[:timeframe]}?latest-#{6*precision_in_secs}s,latest-#{5*precision_in_secs}s,latest-#{4*precision_in_secs}s,latest-#{3*precision_in_secs}s,latest-#{2*precision_in_secs}s")
  prev_body = %x{curl -s "#{prev_timestamp}"}
  body = %x{curl -s "#{timestamps}"}
  json_prev_str = extract_json_string_for_mule_response_body(prev_body)
  json_str = extract_json_string_for_mule_response_body(body)
  mule_prev_graph = json_str ? JSON.parse(json_prev_str): nil
  mule_graph = json_str ? JSON.parse(json_str) : nil
  # last timestamp
  prev_val =  mule_prev_graph['data'].values.first[0]
  # Get an average of prev timestamps
  total_val = 0
  mule_graph['data'].values.first.each do |time_stamp|
    total_val +=  time_stamp[0]
  end 
  val_avg = total_val / mule_graph['data'].values.first.length

  # Get precentage of the diff
  diff_prec =  ((prev_val[0]).to_f / val_avg) * 100

rescue Exception => e
  puts "Error checking mule: #{e.class}: #{e}: #{e.backtrace.join(" ... ")}"
  exit(EXIT_UNKNOWN)
end

message = "Mule reports #{c[:series]} #{c[:timeframe]} value=%d (%d precent of avg=%d ) | value=%d timestamp=%d"


if c[:low_crit] && value < c[:low_crit]
  puts "CRITICAL " + sprintf(message, value, c[:low_crit], value, timestamp)
  sort_piechart(c[:host],c[:port],c[:series],c[:timeframe])
  exit(EXIT_CRITICAL)
end

if c[:crit] && value >= c[:crit]
  puts "CRITICAL " + sprintf(message, value, c[:crit], value, timestamp)
  sort_piechart(c[:host],c[:port],c[:series],c[:timeframe])
  exit(EXIT_CRITICAL)
end

if c[:warn] && value >= c[:warn]
  puts "WARNING " + sprintf(message, value, c[:warn], value, timestamp)
  exit(EXIT_WARNING)
end

if c[:low_warn] && value < c[:low_warn]
  puts "WARNING " + sprintf(message, value, c[:low_warn], value, timestamp)
  exit(EXIT_WARNING)
end

if c[:low_crit_precent] && diff_prec < c[:low_crit_precent]
  puts "CRITICAL " + sprintf(message, prev_val[0], diff_prec, val_avg, prev_val[0], prev_val[2])
  sort_piechart(c[:host],c[:port],c[:series],c[:timeframe])
  exit(EXIT_CRITICAL)
end

if c[:crit_precent] && diff_prec >= c[:crit_precent]
  puts "CRITICAL " + sprintf(message, prev_val[0], diff_prec, val_avg, prev_val[0], prev_val[2])
  sort_piechart(c[:host],c[:port],c[:series],c[:timeframe])
  exit(EXIT_CRITICAL)
end

if c[:warn_precent] && diff_prec >= c[:warn_precent]
  puts "WARNING " + sprintf(message, prev_val[0], diff_prec, val_avg, prev_val[0], prev_val[2])
  exit(EXIT_WARNING)
end

if c[:low_warn_precent] && diff_prec < c[:low_warn_precent]
  puts "WARNING " + sprintf(message, prev_val[0], diff_prec, val_avg ,prev_val[0], prev_val[2])
  exit(EXIT_WARNING)
end

# if warning nor critical trigger, say OK and return performance data
puts "OK " + sprintf(message, prev_val[0], diff_prec, val_avg, prev_val[0], prev_val[2])
