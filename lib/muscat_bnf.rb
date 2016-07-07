# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
#ir[File.dirname(__FILE__) + '*.rb'].each {|file| require file }
require_relative 'muscat_source'

module Marcxml
  class BNF < MuscatSource
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
      @methods = [:change_leader, :change_collection, :add_isil, :change_attribution, :prefix_performance,
                  :split_730, :change_243, :change_593_abbreviation, :change_scoring, :transfer_url,
                  :change_009, :insert_773_ref, :remove_852_duplicate, :map]
    end

    def change_009
      cfield = node.xpath("//marc:controlfield[@tag='009']", NAMESPACE).empty? ? nil : node.xpath("//marc:controlfield[@tag='009']", NAMESPACE)
      return 0 unless cfield
      local_id = cfield.first.content
      tag = Nokogiri::XML::Node.new "datafield", node
      tag['tag'] = '035'
      tag['ind1'] = ' '
      tag['ind2'] = ' '
      sfa = Nokogiri::XML::Node.new "subfield", node
      sfa['code'] = 'a'
      sfa.content = local_id
      tag << sfa
      node.root << tag
      cfield.remove
    end

    def remove_852_duplicate
      datafields=node.xpath("//marc:datafield[@tag='852']", NAMESPACE)
      return 0 if datafields.size <= 1
      datafields[1..-1].each do |df|
        df.remove
      end
    end

    def change_collection
      datafield=node.xpath("//marc:datafield[@tag='100']", NAMESPACE)
      if datafield.empty?
        rename_datafield('240', '130')
      end
    end



    def insert_773_ref
      if BNF.refs.empty?
        BNF.correspondance
      end
      
      subfields=node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='a']", NAMESPACE)
      return 0 if subfields.empty?
      local_ref = subfields.first.content
      rism_ref = BNF.refs[local_ref]
      sfw = Nokogiri::XML::Node.new "subfield", node
      sfw['code'] = 'w'
      sfw.content = rism_ref
      subfields.first.parent << sfw
    end

    def check_material
      result = Hash.new
      subfield=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE)
      if subfield.text=='Collection' || subfield.empty?
        result[:level] = "c"
      else
        result[:level] = "m"
      end
      subfield=node.xpath("//marc:datafield[@tag='762']", NAMESPACE)
      unless subfield.empty?
        result[:level] = "c"
      end

      subfield=node.xpath("//marc:datafield[@tag='773']", NAMESPACE)
      unless subfield.empty?
        result[:level] = "d"
      end

      subfields=node.xpath("//marc:datafield[@tag='593']/marc:subfield[@code='a']", NAMESPACE)
      material = []
      subfields.each do |sf|
        if (sf.text =~ /Ms/) || (sf.text =~ /autog/)
          material << :manuscript
        elsif sf.text =~ /print/
          material << :print
        else
          material << :other
        end
      end
      case
      when material.include?(:manuscript) && material.include?(:print)
        result[:type] = "p"
      when material.include?(:manuscript) && !material.include?(:print)
        result[:type] = "d"
      else
        result[:type] = "c"
      end
      return result
    end

    def change_leader
      leader=node.xpath("//marc:leader", NAMESPACE)[0]
      result=check_material
      code = "n#{result[:type]}#{result[:level]}"
      raise "Leader code #{code} false" unless code.size == 3
      if leader
        leader.content="00000#{code} a2200000   4500"
      else
        leader = Nokogiri::XML::Node.new "leader", node
        leader.content="00000#{code} a2200000   4500"
        node.root.children.first.add_previous_sibling(leader)
      end
      leader
    end


    def self.each_record(filename, &block)
        File.open(filename) do |file|
          Nokogiri::XML::Reader.from_io(file).each do |node|
            if node.name == 'record' and node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
              yield(Nokogiri::XML(node.outer_xml, nil, "UTF-8"))
            end
          end
        end
    end

    #Generating file with correspondance between local_id and rism_id
    def self.correspondance(ifile="../bnf_out.xml")
      require 'yaml'
      file_name = "/tmp/bnf"
      if File.exists?(file_name)
        BNF.refs = YAML.load(File.read(file_name))
      else
        each_record(ifile) do |node|
          cfield = node.xpath("//marc:controlfield[@tag='009']", NAMESPACE).empty? ? nil : node.xpath("//marc:controlfield[@tag='009']", NAMESPACE)
          return 0 unless cfield
          local_id = cfield.first.content
          rism_id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content
          BNF.refs[local_id] = rism_id
        end
        File.open(file_name, 'w') {|f| f.write(YAML.dump(BNF.refs)) }
      end
    end

  end
end

