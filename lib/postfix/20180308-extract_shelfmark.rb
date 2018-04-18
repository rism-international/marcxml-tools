#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'trollop'
require 'ruby-progressbar'
require 'rbconfig'
require 'zip'
require 'pry'
require 'colorize'
YAML::ENGINE.yamler='psych'
#YAML::ENGINE.yamler='syck'
#OPTIONS
opts = Trollop::options do
  version "RISM Marcxml 0.1 (2016.07)"
  banner <<-EOS
This utility program changes MARCXML nodes according to an YAML file. 
Overall required argument is -i [inputfile].

Usage:
   marcxml [-cio] [-aftmrsd] [--with-content --with-linked --with-disjunct --zip --with-limit]
where [options] are:
  EOS
#  opt :infile, "Input-Filename", :type => :strings, :short => "-i"
  opt :outfile, "Output-Filename", :type => :string, :default => "out.xml", :short => '-o'
end

Dir['/home/dev/projects/marcxml-tools/lib/*.rb'].each do |file| 
  require file 
end


connection = OracleDB.new.connection
#Trollop::die :infile, "must exist" if !opts[:infile]
Trollop::die :outfile, "must exist" if opts[:report]

##if opts[:infile].size == 1
#  source_file = opts[:infile].first
#else
#  source_files = opts[:infile]
#end

ofile=File.open(opts[:outfile], "w")
result = {}
  #Start reading stream

curs = connection.exec("select RISMNR, HS from ss_240_new order by RISMNR")
while x = curs.fetch_hash
  rismnr = x['RISMNR']
  rda = x['HS']
  rda_utf8 = rda.encode("iso-8859-1").force_encoding("utf-8") if rda
  rda_utf8.encode!('UTF-8', 'UTF-8', :invalid => :replace)
  result[rismnr] = rda_utf8
end

#curs = connection.exec("select rismnr, h41840 from ss_730_ve order by rismnr")
#while x = curs.fetch_hash
#  rismnr = x['RISMNR']
#  rda = x['H41840']
#  rda_utf8 = rda.encode("iso-8859-1").force_encoding("utf-8") if rda
#  rda_utf8.encode!('UTF-8', 'UTF-8', :invalid => :replace)
#  unless result[rismnr]
#    result[rismnr] = [rda_utf8]
#  else
#    binding.pry
#    result[rismnr] << rda_utf8 unless result[rismnr].include?(rda_utf8)
#    binding.pry
#  end

#end


if ofile
  ofile.write(result.to_yaml)
  ofile.close
  puts "\nCompleted!".green
else
  puts source_file + " is not a file!".red
end
