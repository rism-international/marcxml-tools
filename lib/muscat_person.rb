# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'
require_relative 'transformator'
require_relative 'oracle_db'

module Marcxml
  class MuscatPerson < Transformator
    include Logging
    # Needs connection to OracleDB
    @connection = OracleDB.new.connection
    class << self
      attr_accessor :connection
    end

    attr_accessor :node, :namespace
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods = [:add_isil, :change_gender, :change_individualize, :change_035, :add_profession, 
       :split_510, :add_670_id, :change_cataloging_source, :delete_empty_hs, :map]
    end

    def add_profession
      datafields = node.xpath("//marc:datafield[@tag='559']", NAMESPACE)
      return 0 if datafields.empty?
      datafields.each do |datafield|
        sfk = Nokogiri::XML::Node.new "subfield", node
        sfk['code'] = 'i'
        sfk.content = "profession"
        datafield << sfk
      end
    end

    def split_510
      scoring = node.xpath("//marc:datafield[@tag='510']/marc:subfield[@code='a']", NAMESPACE)
      return 0 if scoring.empty?
      scoring.each do |tag|
        entries = tag.content.split("; ")
        entries.each do |entry|
          curs = MuscatPerson.connection.exec("select k0001 from ksprpd where bvsigl='#{entry}'")
          if db = curs.fetch_hash
            k0001 = db['K0001']
            curs.close
            tag = Nokogiri::XML::Node.new "datafield", node
            tag['tag'] = '510'
            tag['ind1'] = ' '
            tag['ind2'] = ' '
            sfa = Nokogiri::XML::Node.new "subfield", node
            sfa['code'] = 'a'
            sfa.content = entry.strip
            tag << sfa
            sf0 = Nokogiri::XML::Node.new "subfield", node
            sf0['code'] = '0'
            sf0.content = k0001
            tag << sf0
            node.root << tag
          else
            next
          end
        end
      end
      rnode = node.xpath("//marc:datafield[@tag='510']", NAMESPACE).first
      rnode.remove if rnode
    end

    def change_gender
      subfield=node.xpath("//marc:datafield[@tag='039']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_gender(sf.content) }
    end

    def change_individualize
      subfield=node.xpath("//marc:datafield[@tag='042']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_individualize(sf.content) }
    end

    def add_670_id
      lit_ids = {
        "Brown-StrattonBMB" => 1480, 
        "DEUMM/b suppl." => 2957,
        "DEUMM/b" => 1577,          
        "ČSHS" => 1625,
        "EitnerQ" => 1272,
        "FétisB|2" => 1574,
        "FétisB|2 suppl." => 995,
        "Frank-AltmannTL|1|5 suppl." => 2497,
        "Frank-AltmannTL|1|5" => 2497,
        "Grove|6" => 1258,
        "Grove|7" => 3072,                                  
        "Kutsch-RiemensGSL|4" => 30026016,
        "MCL" => 1635,
        "MGG" => 1263,
        "MGG suppl." => 2495,
        "MGG|2/p" => 3828,                                                          
        "MGG|2/s" => 1290,
        "MGG|2 suppl." => 30020107,                                              
        "RISM A/I" => 3806,
        "RISM A/I suppl." => 3808,
        "RISM B/I" => 30000057,
        "SCHML" => 3013,
        "Sohlmans|2" => 1282,
        "StiegerO" => 1231,
        "RiemannL|1|2/p" => 408,
        "RiemannL|1|2/p suppl." => 2496,
        "RiemannL|1|3" => 30026906,
        "VollhardtC 1899" => 1624
      }

      scoring = node.xpath("//marc:datafield[@tag='670']/marc:subfield[@code='a']", NAMESPACE)
      return 0 if scoring.empty?
      scoring.each do |tag|
        entry = tag.content.split(":")[0]
        fd = tag.content.include?(":") ? (tag.content.split(":")[1..-1]).join.strip : ""
        if lit_ids.include?(entry)
          a0001=lit_ids[entry]
        else
          #puts entry
          return 0 if !entry || entry.empty?
          curs = MuscatPerson.connection.exec("select a0001 from akprpd where a0376=:1", entry.force_encoding("ISO-8859-1"))
          if db = curs.fetch_hash
            a0001 = db['A0001']
            curs.close
          else
            next
          end
        end
        sf0 = Nokogiri::XML::Node.new "subfield", node
        sf0['code'] = 'w'
        sf0.content = a0001
        tag.add_next_sibling(sf0)
        sfb = Nokogiri::XML::Node.new "subfield", node
        sfb['code'] = 'b'
        sfb.content = fd
        tag.add_next_sibling(sfb)
        tag.content = entry
      end
    end

    def change_035
      refs = []
      subfields=node.xpath("//marc:datafield[@tag='035']/marc:subfield[@code='a']", NAMESPACE)
      subfields.each do |sf|
        if sf.content =~ /; /
          content = sf.content.gsub("(DE-588a)(VIAF)", "(VIAF)")
          content.split("; ").each do |e|
            refs << {e.split(')')[0][1..-1] => e.split(')')[1] }
          end
        else
          content = sf.content.gsub("(DE-588a)(VIAF)", "(VIAF)")
          content.split("; ").each do |e|
            refs << {e.split(')')[0][1..-1] => e.split(')')[1] }
          end
        end
      end
      refs.each do |h|
        h.each do |k,v|
          tag_024 = Nokogiri::XML::Node.new "datafield", node
          tag_024['tag'] = '024'
          tag_024['ind1'] = '7'
          tag_024['ind2'] = ' '
          sfa = Nokogiri::XML::Node.new "subfield", node
          sfa['code'] = 'a'
          sfa.content = v
          sf2 = Nokogiri::XML::Node.new "subfield", node
          sf2['code'] = '2'
          sf2.content = k.gsub("DE-588a", "DNB")
          tag_024 << sfa << sf2
          subfields.first.parent.add_previous_sibling(tag_024)
        end
      end
      node.xpath("//marc:datafield[@tag='035']", NAMESPACE).first.remove unless subfields.empty?
    end

    def delete_empty_hs
      tag = node.xpath("//marc:datafield[@tag='100']", NAMESPACE)
      subfield_node = node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE)
      if tag.empty? || subfield_node.empty? || subfield_node.text.strip.empty?
        puts self.node
        self.namespace = nil
      end
    end

    def convert_gender(str)
      case str
      when "m"
        return "male"
      when "w"
        return "female"
      else
        return "unknown"
      end
    end

    def convert_individualize(str)
      case str
      when "a"
        return "individualized"
      when "b"
        return "not individualized"
      else
        return "unknown"
      end
    end
  end
end


