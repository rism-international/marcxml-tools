# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
Dir[File.dirname(__FILE__) + '../*.rb'].each {|file| require file }

module Marcxml
  class Moravian < Transformator
    NAMESPACE={'marc' => "http://www.loc.gov/MARC21/slim"}
    include Logging
    @refs = {}
    class << self
      attr_accessor :refs
    end
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods = [:fix_id, :fix_dots, :insert_original_entry, :add_material_layer, :map]
    end

    # Records have string at beginning
    def fix_id
      controlfield = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first
      controlfield.content = controlfield.content.gsub("ocn", "1") 
      links = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE)
      links.each {|link| link.content = link.content.gsub("(OCoLC)", "1")}
    end

    def insert_original_entry
      id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE)[0].content
      tag = Nokogiri::XML::Node.new "datafield", node
      tag['tag'] = '500'
      tag['ind1'] = ' '
      tag['ind2'] = ' '
      sfa = Nokogiri::XML::Node.new "subfield", node
      sfa['code'] = 'a'
      sfa.content = "Original catalogue entry: https://moravianmusic.on.worldcat.org/oclc/#{id[1..-1]}"
      tag << sfa
      node.root << tag
    end
 
    

  end
end

