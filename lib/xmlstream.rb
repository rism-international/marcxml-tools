# encoding: UTF-8
#!/usr/bin/env ruby
require 'nokogiri'

module Marcxml
  # Basic class for reading huge marcxml files
  class Xmlstream
    attr_accessor :ofile

    def initialize(ofile)
      @ofile = ofile
    end

    def header
      ofile.write('<?xml version="1.0" encoding="UTF-8"?>'+"\n"+'<collection xmlns="http://www.loc.gov/MARC21/slim">'+"\n")
    end

    def each_record(filename, &block)
      File.open(filename) do |file|
        Nokogiri::XML::Reader.from_io(file).each do |node|
          if node.name == 'record' || node.name == 'marc:record' and node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
            yield(Nokogiri::XML(node.outer_xml, nil, "UTF-8"))
          end
        end
      end
    end

    alias :read :each_record

    # Method for sorting and appending nodes
    # lt and gt arr replaced, but HTML-entities should be erased completly 
    # 
    def append(record, nodes)
      begin
         nodes.sort_by{|node| [node.attr("tag"), nodes.index(node)]}.each{|node| 
           record.root.add_child(node)}
      rescue
        binding.pry
      end
      #TODO Switch line break
      record_string = record.to_s.gsub("{{brk}}","&lt;br&gt;")
       # .gsub("[","&lt;")
       # .gsub("]","&gt;")

      doc = Nokogiri::XML.parse(record_string) do |config|
        config.noblanks
      end
      ofile.write(doc.remove_namespaces!.root.to_xml :encoding => 'UTF-8')
      #puts start
    end

    def write(record)
      doc = Nokogiri::XML.parse(record.to_s) do |config|
        config.noblanks
      end
      ofile.write(doc.remove_namespaces!.root.to_xml :encoding => 'UTF-8')
    end

    def close
      ofile.write("\n</collection>")
      ofile.close
    end
  end
end

