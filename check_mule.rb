#!/usr/bin/env ruby
#
# Nagios check for Solr server health
# Copyright 37signals, 2008
# Author: Joshua Sierles (joshua@37signals.com)

require 'rubygems'
require 'json'
require 'net/http'
require 'uri'
require 'choice'

EXIT_OK = 0
EXIT_WARNING = 1
EXIT_CRITICAL = 2
EXIT_UNKNOWN = 3

Choice.options do
  header ''
  header 'Specific options:'

  option :warn do
    short '-w'
    long '--warning=VALUE'
    desc 'Warning threshold'
    cast Integer
  end

  option :low_crit do
    short '-l'
    long '--low-crit=VALUE'
    desc 'Low critical threshold'
    cast Integer
  end

  option :crit do
    short '-c'
    long '--critical=VALUE'
    desc 'Critical threshold'
    cast Integer
  end

  option :host do
    short '-h'
    long '--host=VALUE'
    desc 'Solr host'
  end    

  option :port do
    short '-b'
    long '--port=VALUE'
    desc 'Solr port'
  end    

  option :prefix do
    short '-p'
    long '--prefix=VALUE'
    desc 'App prefix'
  end
  
  option :start do
    short '-s'
    long '--start=VALUE'
    desc 'Start index'
  end
  
  option :rows do
    short '-r'
    long  '--rows=VALUE'
    desc 'Number of rows to check for'
    default 10
  end
  
  option :query do
    short '-q'
    long  '--query=VALUE'
    desc 'Query term to search for'
    default "test%0D%0A"
  end

  option :version do
    short '-v'
    long  '--version=VALUE'
    desc 'Specify version'
    default "2.2"
  end
end

c = Choice.choices

message = "Solr reports %d rows (limit=%d) | events=%d"

if c[:crit]

  value = nil
  begin
    url = URI.parse("http://#{c[:host]}:#{c[:port]}/")
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.get("/#{c[:prefix]}/select/?q=#{c[:query]}&version=#{c[:version]}&start=#{c[:start]}&rows=#{c[:rows]}&wt=json")
    end

    solr = JSON.parse(res.body)
    if solr['response'] && solr['response']['numFound']
      value = solr['response']['numFound'].to_i
    end

  rescue Exception => e
   puts "Error checking Solr: #{e.class}: #{e}"
   exit(EXIT_UNKNOWN)
  end
  

  if value < c[:low_crit]
    puts "CRITICAL " + sprintf(message, value, c[:low_crit], value)
    exit(EXIT_CRITICAL)
  end

  if value >= c[:crit]
    puts "CRITICAL " + sprintf(message, value, c[:crit], value)
    exit(EXIT_CRITICAL)
  end

  if c[:warn] && value >= c[:warn]
    puts "WARNING " + sprintf(message, value, c[:warn], value)
    exit(EXIT_WARNING)
  end

else
  puts "Please provide a critical threshold"
  exit
end

# if warning nor critical trigger, say OK and return performance data

puts "OK " + sprintf(message, value, c[:warn], value)
