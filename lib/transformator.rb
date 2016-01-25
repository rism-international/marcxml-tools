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
      rename_datafield(node, '240', '130')
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
end


