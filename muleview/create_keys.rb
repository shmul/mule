#!/usr/bin/env ruby

@names = File.read("names_list.txt").split(/\s/)
root = {}
MAX = 6
MAX_HITS = 1000

def make_node(max_depth)
  ans = {
    name: @names.sample.gsub(/ /,"_"),
    children: []
  }
  if max_depth > 0
    rand(0..MAX).times do
      ans[:children] << make_node(max_depth - 1)
    end
  end
  ans
end

def timestamp(keypath = [], node)
  new_keypath = keypath + [node[:name]]
  name = new_keypath.join(".")
  count = rand(1..MAX_HITS)
  timestamp = Time.now.to_i
  ans = ["#{name} #{count} #{timestamp}"]
  node[:children].each do |child|
    ans << timestamp(new_keypath, child)
  end
  ans.flatten
end

root =  make_node(rand(1..MAX))
timestamp(["root"], root).each do |line|
  puts line
end
