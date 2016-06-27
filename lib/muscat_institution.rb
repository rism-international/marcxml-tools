# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'
require_relative 'transformator'

class Muscat_Institution < Transformator
  include Logging
  attr_accessor :node, :namespace, :methods
  def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
    @namespace = namespace
    @node = node
    @methods = [:add_isil, :change_cataloging_source]
  end

  def change_cataloging_source 
    subfield=node.xpath("//marc:datafield[@tag='040']/marc:subfield[@code='a']", NAMESPACE)
    subfield.each { |sf| sf.content = "DE-633" }
  end

end


