#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'trollop'
require 'ruby-progressbar'
require 'rbconfig'
require 'zip'


#OPTIONS
opts = Trollop::options do
  version "RISM splitter 1.0"
  banner <<-EOS
This utility program splits MARCXML

Usage:
   split [options]
where [options] are:
  EOS

  opt :infile, "Input-Filename", :type => :string
end

Trollop::die :infile, "must exist; you can download it from https://opac.rism.info/fileadmin/user_upload/lod/update/rismAllMARCXML.zip" if !opts[:infile]
source_file=opts[:infile]




# Split HUGE xml files into chunks
# first argument is the file containing marc records
# second is the model name
# third is the offset to start from

SIZE=50000
#Helper method to parse huge files with nokogiri
def each_record(filename, &block)
  File.open(filename) do |file|
    Nokogiri::XML::Reader.from_io(file).each do |node|
      if node.name == 'record' and node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        yield(Nokogiri::XML(node.outer_xml, nil, "UTF-8"))
      end
    end
  end
end


source_file = opts[:infile]
start = 0
ofile=File.open("#{"%06d" % start}.xml", "w")
ofile.write('<?xml version="1.0" encoding="UTF-8"?>'+"\n"+'<collection xmlns="http://www.loc.gov/MARC21/slim">'+"\n")
if File.exists?(source_file)
  each_record(source_file) { |record|
    doc = Nokogiri::XML.parse(record.to_s) do |config|
      config.noblanks
    end

    ofile.write(doc.remove_namespaces!.root.to_xml :encoding => 'UTF-8')
    start+=1
    # IF splitting
    if start % SIZE == 0
      puts start
      ofile.write("</collection>")
      ofile.close
      ofile=File.open("#{"%06d" % start}.xml", "w")
      ofile.write('<collection xmlns="http://www.loc.gov/MARC21/slim">')
    end
    #break if start==100
  }
  ofile.write("\n</collection>")
  ofile.close
  puts "\nCompleted: "+Time.new.strftime("%Y-%m-%d %H:%M:%S")

else
  puts source_file + " is not a file!"
end
