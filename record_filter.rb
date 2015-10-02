#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'trollop'
require 'ruby-progressbar'
require 'rbconfig'
OS=RbConfig::CONFIG['host_os']

#OTIONS
opts = Trollop::options do
  version "RISM record_filter 1.0"
  banner <<-EOS
This utility program searches the complete RISM open data XML-File with parameters of query.yaml

Usage:
   record_search [options]
where [options] are:
  EOS

  opt :query, "Query-Filename", :type => :string, :default => "query.yaml"
  opt :infile, "Input-Filename", :type => :string
  opt :outfile, "Output-Filename", :type => :string, :default => "out.xml"
end

Trollop::die :infile, "must exist; you can download it from https://opac.rism.info/fileadmin/user_upload/lod/update/rismAllMARCXML.zip" if !opts[:infile]
source_file=opts[:infile]
resfile=opts[:outfile]
query=YAML.load_file(opts[:query])

puts "Calculating total size..."
total=0
if OS =~ /linux/
  total =`grep -c "leader" #{source_file}`.to_i
else
  file_size=File.size(source_file)
  if file_size > 800000000
    approx=3700
    total=(file_size / approx).floor
  else
    File.open( source_file, 'r:BINARY' ) do |io|
      io.each do |line| 
        total+=1 if line =~ /leader/
      end
    end
  end
end

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
  #  if found > 1 && found % 10==0
  #    bar.log "#{found} records found."
  #  end
end
ofile.puts("</collection>")
ofile.close
puts "#{found} Records found!"

