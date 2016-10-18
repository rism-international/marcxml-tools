# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative '../logging'
require_relative '../transformator'

module Marcxml
  class MuscatSource < Transformator
    include Logging
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods =  [:change_leader, :change_005, :copy_create_date, :change_material, :change_collection, :add_isil, :change_attribution, :prefix_performance, 
       :split_730, :change_243, :change_593_abbreviation, :change_scoring, :transfer_url, :remove_unlinked_authorities, 
       :split_031t, :remove_852_from_b1, :rename_digitalisat, :copy_roles, :change_300a, :map, :move_852c, :move_490]
    end

    def check_material
      result = Hash.new
      subfield=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE)
      if subfield.text=='Collection'
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
        if (sf.text =~ /manusc/) || (sf.text =~ /autog/)
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

    def change_005
      controlfield=node.xpath("//marc:controlfield[@tag='005']", NAMESPACE)[0]
      if controlfield.content.start_with?('20100250')
        controlfield.content="20050101111111.0"
      end
    end

    def change_collection
      subfield=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE)
      if subfield.text=='Collection'
        node.xpath("//marc:datafield[@tag='100']", NAMESPACE).remove
        rename_datafield('240', '130')
      end
    end

    def delete_anonymus
      subfield=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE)
      if subfield.text=='Anonymus'
        node.xpath("//marc:datafield[@tag='100']", NAMESPACE).remove
      end
    end

    def change_material
      materials=node.xpath("//marc:datafield/marc:subfield[@code='8']", NAMESPACE)
      materials.each do |material|
        begin
          material.content="%02d" % material.content.gsub("\\c", "") if material
        rescue ArgumentError
        end
      end
    end

    def change_scoring
      scoring = node.xpath("//marc:datafield[@tag='594']/marc:subfield[@code='a']", NAMESPACE)
      scoring.each do |tag|
        entries = tag.content.split(/,(?=\s\D)/)
        entries.each do |entry|
          instr = entry.split("(").first
          amount = entry.gsub(/.+\((\w+)\)/, '\1')
          tag = Nokogiri::XML::Node.new "datafield", node
          tag['tag'] = '594'
          tag['ind1'] = ' '
          tag['ind2'] = ' '
          sfa = Nokogiri::XML::Node.new "subfield", node
          sfa['code'] = 'b'
          sfa.content = instr.strip
          sf2 = Nokogiri::XML::Node.new "subfield", node
          sf2['code'] = 'c'
          sf2.content = amount==instr ? 1 : amount
          tag << sfa << sf2
          node.root << tag
        end
      end
      #rnode = node.xpath("//marc:datafield[@tag='594']", NAMESPACE).first
      #rnode.remove if rnode
    end

    def change_attribution
      subfield100=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='j']", NAMESPACE)
      subfield700=node.xpath("//marc:datafield[@tag='700']/marc:subfield[@code='j']", NAMESPACE)
      subfield710=node.xpath("//marc:datafield[@tag='710']/marc:subfield[@code='g']", NAMESPACE)
      subfield100.each { |sf| sf.content = convert_attribution(sf.content) }
      subfield700.each { |sf| sf.content = convert_attribution(sf.content) }
      subfield710.each { |sf| sf.content = convert_attribution(sf.content) }
    end

    def change_593_abbreviation
      subfield=node.xpath("//marc:datafield[@tag='593']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = convert_593_abbreviation(sf.content) }
    end

    def change_300a
      subfield=node.xpath("//marc:datafield[@tag='300']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each do |sf|
        return 0 unless sf.content.include?("St") || sf.content.include?("P") || sf.content.include?("KLA")
        content = []
        sf.content.split(";").each do |c|
          content << convert_300a(c.strip)
        end
        sf.content = content.join("; ")
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

    def transfer_url
      subfields=node.xpath("//marc:datafield[@tag='856']/marc:subfield[@code='u']", NAMESPACE)
      subfields.each do |sf|
        sf2 = Nokogiri::XML::Node.new "subfield", node
        sf2['code'] = 'z'
        sf2.content = 'DIGITALISAT'
        sf.parent << sf2
      end
      subfields=node.xpath("//marc:datafield[@tag='500']/marc:subfield[@code='a']", NAMESPACE)
      subfields.each do |sf|
        if sf.content.ends_with_url?
          if sf.content =~ /dl.rism.info/
            rism_id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content
            logger.debug("DROPPED MULTIMEDIA LINK in #{rism_id}: #{sf.parent.to_s}")
            sf.parent.remove
          else
            urlbem = sf.content.split(": ")[0..-2].join(": ")
            url = sf.content.split(": ")[-1]
            tag_856 = Nokogiri::XML::Node.new "datafield", node
            tag_856['tag'] = '856'
            tag_856['ind1'] = '0'
            tag_856['ind2'] = ' '
            sfa = Nokogiri::XML::Node.new "subfield", node
            sfa['code'] = 'u'
            sfa.content = url.gsub(/\.$/, "")
            sf2 = Nokogiri::XML::Node.new "subfield", node
            sf2['code'] = 'z'
            sf2.content = urlbem
            tag_856 << sfa << sf2
            node.root << tag_856
            sf.parent.remove
          end
        end
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

    def split_031t
      datafields = node.xpath("//marc:datafield[@tag='031']", NAMESPACE)
      return 0 if datafields.empty?
      datafields.each do |datafield|
        txt = datafield.xpath("marc:subfield[@code='t']", NAMESPACE)[0]
        next if !txt || !txt.content.include?(";")
        texts = txt.content.split(";")
        texts.each do |t|
          sfk = Nokogiri::XML::Node.new "subfield", node
          sfk['code'] = 't'
          sfk.content = t.strip
          datafield << sfk
        end
        txt.remove
      end
    end

    def remove_852_from_b1
      series = node.xpath("//marc:datafield[@tag='490']/marc:subfield[@code='a']", NAMESPACE)
      return 0 if series.empty? || series.first.content != 'B/I'
      unless node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE).empty?
        rnode = node.xpath("//marc:datafield[@tag='852']", NAMESPACE)
        rnode.remove
      end
    end

    def copy_roles
      incipit_roles = node.xpath("//marc:datafield[@tag='031']/marc:subfield[@code='e']", NAMESPACE)
      return 0 if incipit_roles.empty?
      existing_roles = []
      node.xpath("//marc:datafield[@tag='595']/marc:subfield[@code='a']", NAMESPACE).each do |e|
        existing_roles << Marcxml::ApplicationHelper.normalize_role(e.content)
      end
      incipit_roles.each do |role|
        normalized_role = Marcxml::ApplicationHelper.normalize_role(role.content)
        if !existing_roles.include?(normalized_role)  
          tag = Nokogiri::XML::Node.new "datafield", node
          tag['tag'] = '595'
          tag['ind1'] = ' '
          tag['ind2'] = ' '
          sfa = Nokogiri::XML::Node.new "subfield", node
          sfa['code'] = 'a'
          sfa.content = normalized_role  
          existing_roles << normalized_role
          tag << sfa
          node.root << tag
        end
      end
    end


    def rename_digitalisat
      subfields = node.xpath("//marc:datafield[@tag='856']/marc:subfield[@code='z']", NAMESPACE)
      return 0 if subfields.empty?
      subfields.each do |subfield|
        if subfield.content == 'DIGITALISAT'
          subfield.content = "[digitized version]"
        end
      end
    end


    def remove_unlinked_authorities
      tags = %w(100$0 504$0 510$0 700$0 710$0 852$x)
      tags.each do |tag|
        df, sf = tag.split("$")
        nodes = node.xpath("//marc:datafield[@tag='#{df}']", NAMESPACE)
        nodes.each do |n|
          subfield = n.xpath("marc:subfield[@code='#{sf}']", NAMESPACE)
          if !subfield || subfield.empty? || (subfield.first.content.empty? || !(subfield.first.content =~ /^[0-9]+$/))
            rism_id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content
            logger.debug("EMPTY AUTHORITY NODE in #{rism_id}: #{n.to_s}")
            if df == '510' and n.xpath("marc:subfield[@code='a']", NAMESPACE).first.content == 'RISM B/I'
              sf0 = Nokogiri::XML::Node.new "subfield", node
              sf0['code'] = '0'
              sf0.content = "30000057"
              n << sf0
            else
              n.remove
            end
          end
        end
      end
    end

    def move_852c
      fields = node.xpath("//marc:datafield[@tag='852']", NAMESPACE)
      fields.each do |field|
        subfields = field.xpath("marc:subfield[@code='c']", NAMESPACE)
        if subfields.size > 1
          rism_id = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content
          logger.debug("DUBLICATE SHELFMARK NODE in #{rism_id}: #{field.to_s}")
          subfields[1..-1].each do |subfield|
            tag = Nokogiri::XML::Node.new "datafield", node
            tag['tag'] = '591'
            tag['ind1'] = ' '
            tag['ind2'] = ' '
            sfa = Nokogiri::XML::Node.new "subfield", node
            sfa['code'] = 'a'
            sfa.content = subfield.content
            tag << sfa
            node.root << tag
            subfield.remove
          end
        end
      end
    end

    def move_490
      series = node.xpath("//marc:datafield[@tag='490']", NAMESPACE)[0]
      series_entry = node.xpath("//marc:datafield[@tag='490']/marc:subfield[@code='a']", NAMESPACE)[0]
      location_entry = node.xpath("//marc:datafield[@tag='035']/marc:subfield[@code='a']", NAMESPACE)[0]
      existent_510 = node.xpath("//marc:datafield[@tag='510']", NAMESPACE)[0]
      return 0 unless series_entry
      if existent_510
        series.remove
      else
        tag = Nokogiri::XML::Node.new "datafield", node
        tag['tag'] = '510'
        tag['ind1'] = ' '
        tag['ind2'] = ' '
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'a'
        sfa.content = "RISM " + series_entry.content
        tag << sfa
        if location_entry
          sfc = Nokogiri::XML::Node.new "subfield", node
          sfc['code'] = 'c'
          sfc.content = location_entry.content
          tag << sfc
        end
        node.root << tag
        series.remove
      end
    end

    def copy_create_date
      date005 = node.xpath("//marc:controlfield[@tag='005']", NAMESPACE)[0]
      return 0 if !date005
      crdate = date005.content[2..7]
      date008 = node.xpath("//marc:controlfield[@tag='008']", NAMESPACE)[0]
      return 0 if !date008
      date008.content = crdate + date008.content[6..-1]
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

    def convert_300a(str)
      case str
      when "KLA"
        return "short score"
      when "P"
        return "score"
      when "St"
        return "part(s)"
      else
        return str
      end
    end

    def split_hs(str)
      str.gsub!(/\?$/, "")
      title={}
      title[:hs] = str unless str.include?(".")
      fields = str.split(".")
      if fields.size == 2
        title[:hs] = fields[0]
        title[:sub] = fields[1].strip if fields[1].strip.size > 3
        title[:arr] = fields[1].strip if fields[1].strip.size <= 3
      elsif fields.size == 3
        title[:hs] = fields[0]
        title[:sub] = fields[1].strip
        title[:arr] = fields[2].strip
      else
        title[:hs] = str
      end
      return title

    end
  end
end


