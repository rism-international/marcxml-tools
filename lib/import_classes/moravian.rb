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
      @methods = [:fix_id, :fix_dots, :map]
    end

    # Records have string at beginning
    def fix_id
      controlfield = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first
      controlfield.content = controlfield.content.gsub("ocn", "1") 
      links = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE)
      links.each {|link| link.content = link.content.gsub("(OCoLC)", "1")}
    end

    # Records have dot or komma at end
    def fix_dots
      fields = %w(100$a 100$d 240$a 300$a 710$a 700$a 700$d)
      fields.each do |field|
        tag, code = field.split("$")
        links = node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE)
        links.each {|link| link.content = link.content.gsub(/[\.,:]$/, "")}
      end

    end



  end
end

