#!/usr/bin/env ruby

require '../lib/storage/redlander.rb'
require '../lib/namespaces/api.rb'

values = []
File.open(ARGV[0], 'r:UTF-8') do |f|
  f.each_line do |line|
    values << line.chomp
  end
end

storage = StorageRedlander.new(:name => "../rdf.db")
api = OpenBEL::Namespace::API.new storage
eq = api.find_equivalents(:hgnc, values, :result => :name, :target => "egid")
eq.each do |x|
  puts "#{x.value}: #{x.equivalences ? x.equivalences.map(&:to_s).join(", ") : "NONE"}"
end
puts eq.size