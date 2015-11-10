#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'trollop'
require 'ruby-progressbar'
require 'rbconfig'
require 'zip'



# Split HUGE xml files into chunks
# first argument is the file containing marc records
# second is the model name
# third is the offset to start from

SIZE=50000
NAMESPACE={'marc' => "http://www.loc.gov/MARC21/slim"}


#
def change_subfield_code(node, tag, old_code, new_code)
      subfield=node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{old_code}']", NAMESPACE)
      subfield.attr('code', new_code) if subfield
      subfield
end

def change_leader(node)
      leader=node.xpath("//marc:leader", NAMESPACE)[0]
      leader.content="00000ccm a2200000   4500"
      leader
end

def change_datafield(node, tag, new_tag)
      datafield=node.xpath("//marc:datafield[@tag='#{tag}']", NAMESPACE)
      datafield.attr('tag', new_tag) if datafield
      datafield
end

def change_collection(node)
      subfield=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE)
      if subfield.text=='Collection'
        node.xpath("//marc:datafield[@tag='100']", NAMESPACE).remove
        change_datafield(node, '240', '110')
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



if ARGV.length >= 1
  source_file = ARGV[0]
  start = 0
  ofile=File.open("change.xml", "w")
  ofile.write('<?xml version="1.0" encoding="UTF-8"?>'+"\n"+'<collection xmlns="http://www.loc.gov/MARC21/slim">'+"\n")
  if File.exists?(source_file)
    each_record(source_file) { |record|
      change_leader(record)
      change_collection(record)
      change_datafield(record, '762', '772')
      change_datafield(record, '035', '036')
      change_datafield(record, '504', '690')
      change_datafield(record, '510', '691')
      change_subfield_code(record,'773', 'a', 'w')

      #Sorting tags
      nodes = record.xpath("//marc:datafield", NAMESPACE).remove
      nodes.sort_by{|node| node.attr("tag")}.each{|node| record.add_child(node)}
      doc = Nokogiri::XML.parse(record.to_s) do |config|
        config.noblanks
      end

      ofile.write(doc.remove_namespaces!.root.to_xml :encoding => 'UTF-8')
      start+=1
        puts start
    }
    ofile.write("\n</collection>")
    ofile.close
    puts "\nCompleted: "+Time.new.strftime("%Y-%m-%d %H:%M:%S")

  else
    puts source_file + " is not a file!"
  end
else
  puts "Bad arguments, specify marc file and model class to use"
end
