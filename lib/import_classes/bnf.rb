# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
Dir[File.dirname(__FILE__) + '../*.rb'].each {|file| require file }

module Marcxml
  class BNF < Transformator
    NAMESPACE={'marc' => "http://www.loc.gov/MARC21/slim"}
    include Logging
    @refs = {}
    @ids = YAML.load_file("/home/dev/projects/import/BNF/id.yml")
    class << self
      attr_accessor :refs, :ids
    end
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods = [:map, :fix_id, :change_leader, :change_collection, :add_isil, :change_attribution, :prefix_performance,
                  :split_730, :change_243, :change_593_abbreviation, :change_009, :add_siglum]
      #:insert_773_ref, 
    end

    def fix_id
      controlfield = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first
      binding.pry
      if ((Integer(controlfield.content) rescue false) == false)
        controlfield.content = BNF.ids[controlfield.content]
      end
      datafield = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE).first rescue nil
      if datafield
        datafield.content = BNF.ids[datafield.content]
      end
      #links = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE)
      #links.each {|link| link.content = link.content.gsub("(OCoLC)", "1")}
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

    def add_siglum
      datafields=node.xpath("//marc:datafield[@tag='852']", NAMESPACE)
      datafields.each do |df|
        sfw = Nokogiri::XML::Node.new "subfield", node
        sfw['code'] = 'a'
        sfw.content = "F-Pn"
        df << sfw
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

    def change_attribution
      subfield100=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='j']", NAMESPACE)
      subfield700=node.xpath("//marc:datafield[@tag='700']/marc:subfield[@code='j']", NAMESPACE)
      subfield710=node.xpath("//marc:datafield[@tag='710']/marc:subfield[@code='g']", NAMESPACE)
      subfield100.each { |sf| sf.content = convert_attribution(sf.content) }
      subfield700.each { |sf| sf.content = convert_attribution(sf.content) }
      subfield710.each { |sf| sf.content = convert_attribution(sf.content) }
    end

    def convert_attribution(str)
      case str
      when "e"
        return "Ascertained"
      when "z"
        return "Doubtful"
      when "g"
        return "Verified"
      when "f"
        return "Misattributed"
      when "l"
        return "Alleged"
      when "m"
        return "Conjectural"
      else
        return str
      end
    end

    def prefix_performance
      subfield=node.xpath("//marc:datafield[@tag='518']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = "Performance date: #{sf.content}" }
    end

    def split_730
      datafields = node.xpath("//marc:datafield[@tag='730']", NAMESPACE)
      return 0 if datafields.empty?
      datafields.each do |datafield|
        hs = datafield.xpath("marc:subfield[@code='a']", NAMESPACE)
        title = split_hs(hs.map(&:text).join(""))
        hs.each { |sf| sf.content = title[:hs] }
        sfk = Nokogiri::XML::Node.new "subfield", node
        sfk['code'] = 'g'
        sfk.content = "RISM"
        datafield << sfk
        if title[:sub]
          sfk = Nokogiri::XML::Node.new "subfield", node
          sfk['code'] = 'k'
          sfk.content = title[:sub]
          datafield << sfk
        end
        if title[:arr]
          sfk = Nokogiri::XML::Node.new "subfield", node
          sfk['code'] = 'o'
          sfk.content = title[:arr]
          datafield << sfk
        end
      end
    end

    def change_243
      tags=node.xpath("//marc:datafield[@tag='243']", NAMESPACE)
      tags.each do |sf|
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'g'
        sfa.content = "RAK"
        sf << sfa
        tags.attr("tag", "730")
      end
    end

    def change_593_abbreviation
      subfield=node.xpath("//marc:datafield[@tag='593']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_593_abbreviation(sf.content) }
    end

 




    def convert_593_abbreviation(str)
      case str
      when "mw"
        return "Other"
      when "mt"
        return "Treatise, handwritten"
      when "ml"
        return "Libretto, handwritten"
      when "mu"
        return "Treatise, printed"
      when "mv"
        return "unknown"
      when "autograph"
        return "Autograph manuscript"
      when "partly autograph"
        return "Partial autograph"
      when "manuscript"
        return "Manuscript copy"
      when "probably autograph"
        return "Possible autograph manuscript"
      when "mk"
        return "Libretto, printed"
      when "mz"
        return "Music periodical"
      when "4"
        return "Other"
      else
        return str
      end
    end





















    

  end
end

