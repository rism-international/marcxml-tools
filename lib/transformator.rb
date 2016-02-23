#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'rbconfig'

class Transformator
  attr_accessor :node, :namespace
  def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
    @namespace = namespace
    @node = node
  end


  def rename_subfield_code(tag, old_code, new_code)
    subfield=node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{old_code}']", NAMESPACE)
    if !node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{new_code}']", NAMESPACE).empty?
      puts "WARNING: #{tag}$#{new_code} already exits!"
    end
    subfield.attr('code', new_code) if subfield
    subfield
  end

  def change_content(tag, code, replacements)
    nodes=node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE)
    nodes.each do |n|
      if replacements[n.text]
        n.content = replacements[n.text]
      end
    end
    nodes
  end

  def move_subfield_to_tag(from_tag, tag)
    ftag=from_tag.split("$")[0]
    fcode=from_tag.split("$")[1]
    target=node.xpath("//marc:datafield[@tag='#{tag}']", NAMESPACE)
    source=node.xpath("//marc:datafield[@tag='#{ftag}']/marc:subfield[@code='#{fcode}']", NAMESPACE)
    if target.empty?
      rename_datafield(ftag, tag) 
    else
      target.children.first.add_previous_sibling(source)
    end
    if node.xpath("//marc:datafield[@tag='#{ftag}']/marc:subfield[@code='*']", NAMESPACE).empty?
      node.xpath("//marc:datafield[@tag='#{ftag}']", NAMESPACE).remove
    end
    target
  end

  def remove_subfield(ftag)
    tag=ftag.split("$")[0]
    code=ftag.split("$")[1]
    node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE).remove
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
      if sf.text =~ /manusc/
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

  def rename_datafield(tag, new_tag)
    if !node.xpath("//marc:datafield[@tag='#{new_tag}']", NAMESPACE).empty?
      puts "WARNING: Tag #{new_tag} already exits!"
    end
    datafield=node.xpath("//marc:datafield[@tag='#{tag}']", NAMESPACE)
    datafield.attr('tag', new_tag) if datafield
    datafield
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

  def zr_addition_change_attribution
    subfield100=node.xpath("//marc:datafield[@tag='100']/marc:subfield[@code='j']", NAMESPACE)
    subfield700=node.xpath("//marc:datafield[@tag='700']/marc:subfield[@code='j']", NAMESPACE)
    subfield710=node.xpath("//marc:datafield[@tag='710']/marc:subfield[@code='g']", NAMESPACE)
    subfield100.each { |sf| sf.content = convert_attribution(sf.content) }
    subfield700.each { |sf| sf.content = convert_attribution(sf.content) }
    subfield710.each { |sf| sf.content = convert_attribution(sf.content) }
  end

  def zr_addition_change_593_abbreviation
    subfield=node.xpath("//marc:datafield[@tag='593']/marc:subfield[@code='a']", NAMESPACE)
    subfield.each { |sf| sf.content = convert_593_abbreviation(sf.content) }
  end

  def zr_addition_change_gender
    subfield=node.xpath("//marc:datafield[@tag='039']/marc:subfield[@code='a']", NAMESPACE)
    subfield.each { |sf| sf.content = convert_gender(sf.content) }
  end

  def zr_addition_change_035
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



  def zr_addition_prefix_performance
    subfield=node.xpath("//marc:datafield[@tag='518']/marc:subfield[@code='a']", NAMESPACE)
    subfield.each { |sf| sf.content = "Performance date: #{sf.content}" }
  end

  def zr_addition_add_isil
    controlfield=node.xpath("//marc:controlfield[@tag='003']", NAMESPACE)
    controlfield.each { |sf| sf.content = "DE-633" }
  end

  def zr_addition_split_730
    datafields = node.xpath("//marc:datafield[@tag='730']", NAMESPACE)
    return 0 if datafields.empty?
    datafields.each do |datafield|
      hs = datafield.xpath("marc:subfield[@code='a']", NAMESPACE)
      title = split_hs(hs.map(&:text).join(""))
      hs.each { |sf| sf.content = title[:hs] }
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
    when "a"
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
      return "other type"
    when "mt"
      return "theoreticum, handwritten"
    when "ml"
      return "libretto, handwritten"
    when "mu"
      return "theoreticum, printed"
    when "mv"
      return "unknown"
    else
      return str
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


