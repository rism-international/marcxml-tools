# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative '../logging'
require_relative '../transformator'

module Marcxml
  class OpacSource < Transformator
    include Logging
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      #@methods =  [:change_leader, :change_005, :copy_create_date, :change_material, :change_collection, 
      #  :add_isil, :change_attribution, :prefix_performance, 
      # :split_730, :change_243, :change_593_abbreviation, :change_scoring, :remove_unlinked_authorities, 
      # :split_031t, :remove_852_from_b1, :rename_digitalisat, :copy_roles, :change_300a, :move_300a, :change_700_relator,
      # :change_260c,
      # :map, :move_852c, :move_490]

      @methods = [:change_material, :change_collection, :change_attribution, :prefix_performance,
                  :join_730, :change_243, :change_593_abbreviation, :change_scoring,
                  :join_031t, :rename_digitalisat, :move_590b, :change_700_relator, :move_490,
                  :move_772_with_b1, :generate_incipit_id, :add_incipit_id, :add_layer_for_copyists,
                  #, :copy_690_to_240n

                  :map]
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
      if subfield.empty?
        tag = Nokogiri::XML::Node.new "datafield", node
        tag['tag'] = '100'
        tag['ind1'] = ' '
        tag['ind2'] = ' '
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'a'
        sfa.content = "Collection"
        tag << sfa
        node.root << tag
        rename_datafield('130', '240')
      end
    end

    def move_772_with_b1
      isn = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content rescue "0"
      if isn.start_with?("00000993")
        d100 = node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='a']", NAMESPACE).first.content rescue ""
        if d100 == 'Collection'
          rename_datafield('774', '772')
        end
        links_to_collection = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE)
        links_to_collection.each do |link|
          link.content = "%014d" % link.content.to_i
        end
      else
        links_to_collection = node.xpath("//marc:datafield[@tag='773']/marc:subfield[@code='w']", NAMESPACE)
        links_to_collection.each do |link|
          if link.content.start_with?("993")
            link.content = "%014d" % link.content.to_i
          else
            link.content = "%09d" % link.content.to_i
            link.attributes["code"].value = "a"
          end
        end
        links_to_preprint = node.xpath("//marc:datafield[@tag='775']/marc:subfield[@code='w']", NAMESPACE)
        links_to_preprint.each do |link|
          link.content = "%014d" % link.content.to_i
          #binding.pry
        end
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
          material.content="#{material.content.gsub(/^0/, "")}\\c" if material
        rescue ArgumentError
        end
      end
    end

    def change_scoring
      scoring = node.xpath("//marc:datafield[@tag='594']/marc:subfield[@code='b']", NAMESPACE)
      scoring.each do |tag|
        tag.parent.remove
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

    def change_700_relator
      subfield700=node.xpath("//marc:datafield[@tag='700']/marc:subfield[@code='4']", NAMESPACE)
      subfield700.each { |sf| sf.content = convert_700_relator(sf.content) }
    end

    def add_layer_for_copyists
      tags=node.xpath("//marc:datafield[@tag='700']", NAMESPACE)
      tags.each do |tag|
        if tag.xpath("marc:subfield[@code='8']", NAMESPACE).empty?
          begin
            if tag.xpath("marc:subfield[@code='4']", NAMESPACE).first.content == "scr"
              sf2 = Nokogiri::XML::Node.new "subfield", node
              sf2['code'] = '8'
              sf2.content = '1\c'
              tag << sf2
            end
          rescue 
            next
          end
        end
      end
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

    def change_260c
      subfield=node.xpath("//marc:datafield[@tag='260']/marc:subfield[@code='c']", NAMESPACE)
      subfield.each do |sf|
        if sf.content =~ /0000/
          sf.content = sf.content.gsub("0000", "")
        end
      end
    end

    def change_243
      tags=node.xpath("//marc:datafield[@tag='730']", NAMESPACE)
      tags.each do |tag|
        ruling = tag.xpath("marc:subfield[@code='g']", NAMESPACE).first
        if ruling && ruling.content == 'RAK'
          tag["tag"] = "243"
        end
      end
    end

    def transfer_url
      url_nodes = node.xpath("//marc:datafield[@tag='856']", NAMESPACE)
      return 0 if url_nodes.empty?
      url_nodes.each do |n|
        urlbem = n.xpath("marc:subfield[@code='z']", NAMESPACE)
        if urlbem.empty?
          sf2 = Nokogiri::XML::Node.new "subfield", node
          sf2['code'] = 'z'
          sf2.content = 'DIGITALISAT'
          n << sf2
        end
      end
    end

    def prefix_performance
      subfield=node.xpath("//marc:datafield[@tag='518']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = sf.content.gsub("Performance date: ", "") }
    end


    def join_730
      datafields = node.xpath("//marc:datafield[@tag='730']", NAMESPACE)
      return 0 if datafields.empty?
      datafields.each do |datafield|
        sub = ""
        arr = ""
        hs = datafield.xpath("marc:subfield[@code='a']", NAMESPACE).first
        node_sub = datafield.xpath("marc:subfield[@code='k']", NAMESPACE).first
        node_arr = datafield.xpath("marc:subfield[@code='o']", NAMESPACE).first
        if node_sub
          sub = ". " + node_sub.content
          node_sub.remove
        end
        if node_arr
          arr = ". " + node_arr.content
          node_arr.remove
        end
        hs.content = hs.content + sub + arr
      end
    end

    def join_031t
      datafields = node.xpath("//marc:datafield[@tag='031']", NAMESPACE)
      return 0 if datafields.empty?
      datafields.each do |datafield|
        texts = datafield.xpath("marc:subfield[@code='t']", NAMESPACE)
        next if texts.size <= 1
        texts[1..-1].each do |t|
          texts[0].content += "; #{t.content}"
          t.remove
        end
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

    def generate_incipit_id
      isn = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content rescue nil
      migrated = isn.start_with?("55301") ? true : false
      return if isn.to_i < 1001000000 && !migrated
      incipit = node.xpath("//marc:datafield[@tag='031']", NAMESPACE)
      incipit.each do |n|
        copied_link = n.xpath("marc:subfield[@code='u']", NAMESPACE).first
        copied_link.remove if copied_link
        a = n.xpath("marc:subfield[@code='a']", NAMESPACE).first.content rescue ""
        b = n.xpath("marc:subfield[@code='b']", NAMESPACE).first.content rescue ""
        c = n.xpath("marc:subfield[@code='c']", NAMESPACE).first.content rescue ""
        adding_numbers = "#{a}#{b}#{c}" rescue nil
        if isn && adding_numbers
          incipit_id = "#{isn}#{adding_numbers}"
        end
        sfa = Nokogiri::XML::Node.new "subfield", node
        sfa['code'] = 'u'
        sfa.content = incipit_id
        n << sfa
      end
    end

    #if there isn't a incipit id at subfield $u at all
    def add_incipit_id
      isn = node.xpath("//marc:controlfield[@tag='001']", NAMESPACE).first.content rescue nil
      incipit = node.xpath("//marc:datafield[@tag='031']", NAMESPACE)
      incipit.each do |n|
        existent = n.xpath("marc:subfield[@code='u']", NAMESPACE).first
        pae = n.xpath("marc:subfield[@code='p']", NAMESPACE).first
        if existent
          next
        elsif !pae
          next
        else
          binding.pry
          a = n.xpath("marc:subfield[@code='a']", NAMESPACE).first.content rescue ""
          b = n.xpath("marc:subfield[@code='b']", NAMESPACE).first.content rescue ""
          c = n.xpath("marc:subfield[@code='c']", NAMESPACE).first.content rescue ""
          adding_numbers = "#{a}#{b}#{c}" rescue nil
          if isn && adding_numbers
            incipit_id = "#{isn}#{adding_numbers}"
          end
          sfa = Nokogiri::XML::Node.new "subfield", node
          sfa['code'] = 'u'
          sfa.content = incipit_id
          n << sfa
        end
      end
    end

    def rename_digitalisat
      subfields = node.xpath("//marc:datafield[@tag='856']/marc:subfield[@code='z']", NAMESPACE)
      return 0 if subfields.empty?
      subfields.each do |subfield|
        if subfield.content =~ /^\[digitized version\]/
          if subfield.content == '[digitized version]'
            subfield.content = "Digitalisat"
          else
            subfield.content = "Digitalisat #{subfield.content}"
          end
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

    def copy_690_to_240n
      node_240n = node.xpath("//marc:datafield[@tag='240']/marc:subfield[@code='n']", NAMESPACE)
      node_240 = node.xpath("//marc:datafield[@tag='240']", NAMESPACE).first
      nodes_690 = node.xpath("//marc:datafield[@tag='690']", NAMESPACE)
      if nodes_690.empty?
        return 0
      end
      node_240n_content = node_240n.map { |n| n.content }
      nodes_690.each do |node|
        wv = node.xpath("marc:subfield[@code='a']", NAMESPACE).first.content rescue ""
        no = node.xpath("marc:subfield[@code='n']", NAMESPACE).first.content rescue ""
        content = "#{wv} #{no}"
        unless node_240n_content.include?(content)
          sfn = Nokogiri::XML::Node.new "marc:subfield", node
          sfn['code'] = 'n'
          sfn.content = content
          node_240 << sfn
        end
      end
    end

    def move_490
      series_entry = node.xpath("//marc:datafield[@tag='510']/marc:subfield[@code='a']", NAMESPACE)[0]
      return 0 unless series_entry
      tag = Nokogiri::XML::Node.new "datafield", node
      tag['tag'] = '490'
      tag['ind1'] = ' '
      tag['ind2'] = ' '
      sfa = Nokogiri::XML::Node.new "subfield", node
      sfa['code'] = 'a'
      sfa.content = series_entry.content.gsub("RISM ", "")
      tag << sfa
      node.root << tag
      series_entry.parent.remove
    end

    def copy_create_date
      date005 = node.xpath("//marc:controlfield[@tag='005']", NAMESPACE)[0]
      return 0 if !date005
      crdate = date005.content[2..7]
      date008 = node.xpath("//marc:controlfield[@tag='008']", NAMESPACE)[0]
      return 0 if !date008
      date008.content = crdate + date008.content[6..-1]
    end

    def move_590b
      extend_nodes = node.xpath("//marc:datafield[@tag='590']/marc:subfield[@code='b']", NAMESPACE)
      return 0 if extend_nodes.empty?
      material_levels = {}
      extend_nodes.each do |sf|
        sf_590_8 = sf.xpath("../marc:subfield[@code='8']", NAMESPACE).first
        material_levels[sf_590_8.content] = sf.content unless sf.content.empty?
        sf.remove 
      end

      nodes_in_300 = node.xpath("//marc:datafield[@tag='300']/marc:subfield[@code='8']", NAMESPACE)
      nodes_in_300.each do |node|
        if material_levels.include?(node.content)
          sf_300_a = node.xpath("../marc:subfield[@code='a']", NAMESPACE).first
          next unless sf_300_a
          sf_300_a.content += ": #{material_levels[node.content]}"
        end
      end
    end

    def convert_attribution(str)
      case str
      when "Ascertained"
        return "e"
      when "Doubtful"
        return "z"
      when "Verified"
        return "g"
      when "Misattributed"
        return "f"
      when "Alleged"
        return "l"
      when "Conjectural"
        return "m"
      else
        return str
      end
    end

    def convert_593_abbreviation(str)
      case str
      when "Autograph manuscript"
        return "autograph"
      when "Partial autograph"
        return "partly autograph"
      when "Manuscript copy"
        return "manuscript"
      when "Possible autograph manuscript"
        return "probably autograph"
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

    def convert_700_relator(str)
      case str
      when "ctb"
        return "clb"
      when "oth"
        return "asn"
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


