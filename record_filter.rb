#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'trollop'
require 'ruby-progressbar'



#100.times do 
#  bar.increment 
#  sleep 0.1 
#end


total=0
#OTIONS
opts = Trollop::options do
    version "RISM record_filter 1.0"
    banner <<-EOS
This utility program searches the complete RISM open data XML-File with parameters of query.yaml

Usage:
   record_search [options]
where [options] are:
EOS

  opt :conf, "Configuration-Filename", :type => :string, :default => "query.yaml"
  opt :total, "Count record total", :default => false
  opt :infile, "Input-Filename", :type => :string
  opt :outfile, "Output-Filename", :type => :string, :default => "out.xml"
end

Trollop::die :infile, "must exist; you can download it from https://opac.rism.info/fileadmin/user_upload/lod/update/rismAllMARCXML.zip" if !opts[:infile]
source_file=opts[:infile]
resfile=opts[:outfile]
query=YAML.load_file(opts[:conf])

if opts[:total]
  puts "Calculating total size..."
  File.open source_file do |file|
    file.each_line do |line|
      if line =~ /leader/ 
        total+=1
      end
    end
  end
else
total= 1040000
end
puts "Total: #{total}"

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

cnt=1
found=0
ofile=File.open(resfile, 'w')

ofile.write('<?xml version="1.0" encoding="UTF-8"?>'+"\n"+'<collection>'+"\n")


bar = ProgressBar.create(title: "Found", :format => "%c of %C Records checked. -- %a | %B | %p%% %e", total: total, remainder_mark: '-', progress_mark: '#')
#QUERY
each_record(source_file) do |record|
  result={}
  query.each do |k,v|
    if k.include?('$')
      df=k.split("$")[0]
      sf=k.split("$")[1]
      res=record.xpath('//datafield[@tag="'+df+'"]/subfield[@code="'+sf+'"]')
    else
      res=record.xpath('//controlfield[@tag="'+k+'"]')
    end
    res.each do |node|
      if node.content =~ /#{v}/
        result[k]=true
      end
    end
  end
  cnt+=1
  #if TOTAL % cnt == 0
  #end
  #RESULT
  if result.size==query.size
      found+=1
      n=Nokogiri::XML(record.to_s, &:noblanks)
      ofile.puts(n.root.to_xml :indent => 4)
  end
  #print "\rRecords: #{cnt+=1}"+"\t\t"+"Found: #{found}"
  bar.increment
end
ofile.puts("</collection>")
ofile.close
puts "\n"
puts "Completed!"
puts "Records: #{cnt+=1}"+" /  "+"Found: #{found}"

