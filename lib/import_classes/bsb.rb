# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
Dir[File.dirname(__FILE__) + '../*.rb'].each {|file| puts file; require file }

# Class for mofifyiung of RISM OPAC at BSB
module Marcxml
  class BSB < Transformator
    include Logging
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods =  [:add_material_to_copyist]
    end

    # This method add a material linkage to copyists in the first material
    def add_material_to_copyist(filtering=true)
      modified = false
      datafields = node.xpath("//marc:datafield[@tag='700']", NAMESPACE)
      if datafields.empty?
        self.namespace = nil
        return 0
      end
      datafields.each do |df|
        if !df.xpath("marc:subfield[@code='8']", NAMESPACE).empty?
          next
        end
        subfield = df.xpath("marc:subfield[@code='4']", NAMESPACE)
        if subfield.first && subfield.first.content != 'scr'
          next
        else
          rism_id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content
          logger.debug("COPYIST WITHOUT MATERIAL in #{rism_id}: #{df.to_s}")
          modified = true
          sf8 = Nokogiri::XML::Node.new "subfield", node
          sf8['code'] = '8'
          sf8.content = '1\c'
          df << sf8
        end
      end
      if filtering
        self.namespace = nil unless modified
      end
    end

  end
end

