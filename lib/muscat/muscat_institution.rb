# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative '../logging'
require_relative '../transformator'

module Marcxml
  class MuscatInstitution < Transformator
    include Logging 
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods = [:add_isil, :change_cataloging_source, :repair_leader, :change_type, :map]
    end

    def change_cataloging_source 
      subfield=node.xpath("//marc:datafield[@tag='040']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = "DE-633" }
    end
    
    def change_type
      subfield=node.xpath("//marc:datafield[@tag='710']/marc:subfield[@code='4']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_type(sf.content) }
    end

    def convert_type(str)
      case str
      when "K"
        return "Institution"
      when "K; B"
        return "Library"
      when "B; K"
        return "Library"
      when "B"
        return "Library"      
      when "V"
        return "Publisher"
      else
        return "Other"
      end
    end


  end
end


