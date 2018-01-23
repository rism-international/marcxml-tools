# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'

module Marcxml
  # Parent class for modifying Marcxml
  class Transformator
    include Logging
    @mapping = {}
    class << self
      attr_accessor :mapping
    end

    attr_accessor :node, :namespace, :methods
    def initialize(node, config, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @methods = [:map]
    end
    
    def rename_subfield_code(tag, old_code, new_code)
      subfield=node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{old_code}']", NAMESPACE)
      if !subfield.empty? && !node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{new_code}']", NAMESPACE).empty?
        puts "WARNING: #{tag}$#{new_code} already exits!".red
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

    def move_subfield_to_datafield(from_tag, tag)
      ftag=from_tag.split("$")[0]
      fcode=from_tag.split("$")[1]
      ttag=tag.split("$")[0]
      tcode=tag.split("$")[1]
      sources=node.xpath("//marc:datafield[@tag='#{ftag}']/marc:subfield[@code='#{fcode}']", NAMESPACE)
      sources.each do |s| 
        target = Nokogiri::XML::Node.new "datafield", node
        target['tag'] = ttag
        target['ind1'] = ' '
        target['ind2'] = ' '
        sf = Nokogiri::XML::Node.new "subfield", node
        sf['code'] = tcode
        sf.content = s.content
        target << sf
        node.root << target
        s.remove
      end
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

    def remove_datafield(tag)
      node.xpath("//marc:datafield[@tag='#{tag}']", NAMESPACE).remove
    end

    def remove_controlfield(tag)
      node.xpath("//marc:controlfield[@tag='#{tag}']", NAMESPACE).remove
    end

    def remove_field(tag)
      if tag.to_i < 10
        remove_controlfield(tag)
      else
        remove_datafield(tag)
      end
    end

    def rename_datafield(tag, new_tag)
      if !node.xpath("//marc:datafield[@tag='#{new_tag}']", NAMESPACE).empty? && !node.xpath("//marc:datafield[@tag='#{tag}']", NAMESPACE).empty?
        puts "WARNING: Tag #{new_tag} already exits!"
      end
      datafield=node.xpath("//marc:datafield[@tag='#{tag}']", NAMESPACE)
      datafield.attr('tag', new_tag) if datafield
      datafield
    end

    def add_isil
      controlfield=node.xpath("//marc:controlfield[@tag='003']", NAMESPACE)
      controlfield.each { |sf| sf.content = "DE-633" }
    end

    def change_cataloging_source 
      subfield=node.xpath("//marc:datafield[@tag='040']/marc:subfield[@code='a']", NAMESPACE)
      subfield.each { |sf| sf.content = "DE-633" }
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

    def execute_all
      methods.each do |method|
        if method.is_a?(Hash)
          method.each do |k,v|
            self.send(k, *v)
          end
        else
          self.send(method) 
        end
      end
    end

    def map
      return 0 if !Transformator.mapping
      Transformator.mapping.each do |entry| 
         entry.each do |k,v|
          if !v && k.is_tag_with_subfield?
            remove_subfield(k)
          elsif !v && k.is_tag?
            remove_datafield(k)
          # Rename datafield
          elsif k.is_tag? && v.is_tag?
            rename_datafield(k, v)
          # Rename subfield
          elsif k.is_tag_with_subfield? && v.is_subfield?
            tag=k.split("$")[0]
            old_sf=k.split("$")[1]
            new_sf=v
            rename_subfield_code(tag, old_sf, new_sf)
           # Move subfield
          elsif k.is_tag_with_subfield? && v.is_tag?
             move_subfield_to_tag(k, v)
          elsif k.is_tag_with_subfield? && v.is_tag_with_subfield?
              move_subfield_to_datafield(k, v)
          end
        end
      end
    end

    def repair_leader
      leader = node.xpath("//marc:leader", NAMESPACE).first
      leader.content = leader.content.gsub(/#/," ")
    end

    def insert_leader
      leader = node.xpath("//marc:leader", NAMESPACE).first
      unless leader
        leader = Nokogiri::XML::Node.new "leader", node
        # Dummy leader
        leader.content="00000ndd a2200000 u 4500"
        node.root.children.first.add_previous_sibling(leader)
      end
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

    # Add missing material layer for different fields
    def add_material_layer
      layers = %w(260 300 592)
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
    
    # Puts fullname in subfield $a if we have firstname in $b
    def concat_personal_name
      fields = %w(100 700)
      fields.each do |field|
        people = node.xpath("//marc:datafield[@tag='#{field}']", NAMESPACE)
        people.each do |person|
          name_a = person.xpath("marc:subfield[@code='a']", NAMESPACE).first rescue nil
          name_b = person.xpath("marc:subfield[@code='b']", NAMESPACE).first rescue nil
          if name_a && name_b 
            last_name = name_a.content rescue ""
            first_name = name_b.content rescue "" 
            full_name = "#{last_name}, #{first_name}"
            name_a.content = full_name
            name_b.remove
          end
        end
      end
    end

    def clear_unknown_muscat_fields(conf)
      node.xpath("//marc:controlfield", NAMESPACE).each do |t|
        tag = t.attr("tag")
        if !conf.keys.include?(tag)
          t.remove
        end
      end
      node.xpath("//marc:datafield", NAMESPACE).each do |t|
        tag = t.attr("tag")
        if !conf.keys.include?(tag)
          t.remove
        else
          t.xpath("marc:subfield",  NAMESPACE).each do |s|
            code = s.attr("code")
            if !conf[tag].include?(code)
              s.remove
            end
          end
        end
        if t.xpath("marc:subfield",  NAMESPACE).empty?
          t.remove
        end
      end

    end

  end
end


