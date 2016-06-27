# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'
require_relative 'transformator'

class MuscatCatalogue < Transformator
  include Logging
  attr_accessor :node, :namespace, :methods
  def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
    @namespace = namespace
    @node = node
    @methods = [:add_isil, :change_media, :remove_datafield => [508]]
  end

  def change_media
    subfield=node.xpath("//marc:datafield[@tag='337']/marc:subfield[@code='a']", NAMESPACE)
    subfield.each { |sf| sf.content = convert_media(sf.content) }
  end

  def convert_media(str)
    case str
    when "0"
      return "Printed book"
    when "ae"
      return "Sheet music"
    when "1"
      return "Manuscript"
    when "er"
      return "Electronic resource"
    when "aj"
      return "CD-ROM"
    when "ak"
      return "Combination"
    else
      return "Other"
    end
  end
end


