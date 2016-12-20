# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative '../logging'
require_relative '../transformator'

module Marcxml
  class OpacCatalogue < Transformator
    include Logging
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      #@methods = [:add_isil, :change_media, :change_ks_relator, :repair_leader, :add_short_title, :map]
      @methods = [:insert_leader, :map]
    end

    def change_media
      subfield=node.xpath("//marc:datafield[@tag='337']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_media(sf.content) }
    end

    def change_ks_relator
      subfield=node.xpath("//marc:datafield[@tag='710']/marc:subfield[@code='4']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_ks_relator(sf.content) }
    end

    def add_short_title
      return 0 unless node.xpath("//marc:datafield[@tag='210']/marc:subfield[@code='a']", NAMESPACE).empty?
      if a = node.xpath("//marc:datafield[@tag='700']/marc:subfield[@code='a']", NAMESPACE)[0]
        author = a.content.split(",").first
      else
        author = ""
      end
      if y = node.xpath("//marc:datafield[@tag='260']/marc:subfield[@code='c']", NAMESPACE)[0]
        year = y.content
      else
        year = ""
      end
      if t = node.xpath("//marc:datafield[@tag='240']/marc:subfield[@code='a']", NAMESPACE)[0]
        title = t.content.split(" ")[0..2].join("")
      else
        title = "xxxx"
      end
      short_title = "#{author}#{title} #{year}"
      tag = Nokogiri::XML::Node.new "datafield", node
          tag['tag'] = '210'
          tag['ind1'] = ' '
          tag['ind2'] = ' '
          sfa = Nokogiri::XML::Node.new "subfield", node
          sfa['code'] = 'a'
          sfa.content = short_title
          tag << sfa
          node.root << tag
    end



    def convert_media(str)
      case str
      when "0"
        return "Printed medium"
      when "ae"
        return "Printed music"
      when "1"
        return "Manuscript"
      when "er"
        return "Electronic resource"
      when "aj"
        return "CD-ROM"
      when "ak"
        return "Media combination"
      when "eb"
        return "E-book"
      when "l"
        return "Microfiche"
      when "o"
        return "Microfilm"
      else
        return "Other"
      end
    end

    def convert_ks_relator(str)
      case str
      when "A"
        return "dnr"
      when "B"
        return "fmo"
      when "E"
        return "prf"
      when "H"
        return "edt"
      when "P"
        return "asn"
      when "WI"
        return "dte"
      else
        return str
      end
    end


  end

end
