#!/usr/bin/env ruby
require 'nokogiri'

class Xmlstream
  attr_accessor :ofile

  def initialize(ofile)
    @ofile = ofile
    ofile.write('<?xml version="1.0" encoding="UTF-8"?>'+"\n"+'<collection xmlns="http://www.loc.gov/MARC21/slim">'+"\n")
  end

  def each_record(filename, &block)
    File.open(filename) do |file|
      Nokogiri::XML::Reader.from_io(file).each do |node|
        if node.name == 'record' and node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
          yield(Nokogiri::XML(node.outer_xml, nil, "UTF-8"))
        end
      end
    end
  end

  alias :read :each_record

  def append(record, nodes)
    nodes.sort_by{|node| node.attr("tag")}.each{|node| 
      record.root.add_child(node)}
    doc = Nokogiri::XML.parse(record.to_s) do |config|
      config.noblanks
    end
    ofile.write(doc.remove_namespaces!.root.to_xml :encoding => 'UTF-8')
    #puts start
  end

  def close
    ofile.write("\n</collection>")
    ofile.close
  end




end

