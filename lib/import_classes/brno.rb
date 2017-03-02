# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
Dir[File.dirname(__FILE__) + '../*.rb'].each {|file| require file }

module Marcxml
  class Brno < Transformator
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
      @methods = [:change_leader, :fix_dots, :fix_incipit_no, :copy_650, :add_material_layer, 
                  :add_catalogue_agency, :insert_852, :insert_original_entry, :map]
    end

    # Change leader to muscat
    def change_leader
      leader=node.xpath("//marc:leader", NAMESPACE)[0]
      if leader
        leader.content=leader.content.sub(/^...../, "00000" )
      end
    end

    def add_material_layer
      layers = %w(260 300)
      layers.each do |l|
        material = node.xpath("//marc:datafield[@tag='#{l}']", NAMESPACE)
        material.each do |block|
          next unless block.xpath("marc:subfield[@code='8']", NAMESPACE).empty?
          sf8 = Nokogiri::XML::Node.new "subfield", node
          sf8['code'] = '8'
          sf8.content = "01"
          block << sf8
        end
      end
    end

    def insert_original_entry
      id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE)[0].content
      tag = Nokogiri::XML::Node.new "datafield", node
      tag['tag'] = '500'
      tag['ind1'] = ' '
      tag['ind2'] = ' '
      sfa = Nokogiri::XML::Node.new "subfield", node
      sfa['code'] = 'a'
      sfa.content = "Original catalogue entry: https://vufind.mzk.cz/Record/MZK01-#{id}"
      tag << sfa
      node.root << tag
    end
    
    def add_catalogue_agency
      tag = Nokogiri::XML::Node.new "datafield", node
      tag['tag'] = '040'
      tag['ind1'] = ' '
      tag['ind2'] = ' '
      sfa = Nokogiri::XML::Node.new "subfield", node
      sfa['code'] = 'a'
      sfa.content = "CZ-Bu"
      tag << sfa
      sfc = Nokogiri::XML::Node.new "subfield", node
      sfc['code'] = 'c'
      sfc.content = "DE-633"
      tag << sfc
      node.root << tag
    end


    # Copy 650 to 240 if no 240 exists
    def copy_650
      et = node.xpath("//marc:datafield[@tag='240']", NAMESPACE)
      genre = node.xpath("//marc:datafield[@tag='650']/marc:subfield[@code='a']", NAMESPACE)
      if et.empty?
        new_et = genre.first.content.capitalize rescue "Pieces"
        tag = Nokogiri::XML::Node.new "datafield", node
        tag['tag'] = '240'
        tag['ind1'] = ' '
        tag['ind2'] = ' '
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'a'
        sfa.content = new_et.sub(/\s{1}\(.*$/, "").sub(/\s{1}\-.*$/, "")
        tag << sfa
        node.root << tag
      end
    end

    #insert siglum
    def insert_852
      siglum = node.xpath("//marc:datafield[@tag='852']", NAMESPACE)
      shelfmark = node.xpath("//marc:datafield[@tag='910']/marc:subfield[@code='b']", NAMESPACE)
      if siglum.empty?
        new_shelfmark = shelfmark.first.content rescue "[without shelfmark]"
        tag = Nokogiri::XML::Node.new "datafield", node
        tag['tag'] = '852'
        tag['ind1'] = ' '
        tag['ind2'] = ' '
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'a'
        sfa.content = "CZ-Bu"
        tag << sfa
        sfc = Nokogiri::XML::Node.new "subfield", node
        sfc['code'] = 'c'
        sfc.content = new_shelfmark
        tag << sfc
        node.root << tag
      end
 

    end

    # Records have dot or komma at end
    def fix_dots
      fields = %w(100$a 100$d 240$a 300$a $650a 710$a 700$a 700$d)
      fields.each do |field|
        tag, code = field.split("$")
        links = node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE)
        links.each {|link| link.content = link.content.gsub(/[\.,:]$/, "")}
      end
    end

    def fix_incipit_no
      incipits = node.xpath("//marc:datafield[@tag='031']", NAMESPACE)
      incipits.each do |incipit|
        nos = %w(a b c)
        nos.each do |no|
          n = incipit.xpath("marc:subfield[@code='#{no}']", NAMESPACE).first rescue nil
          if n
            n.content = n.content.to_i.to_s
          end
        end
      end
    end


  end
end

