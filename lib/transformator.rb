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

    def rename_datafield(tag, new_tag)
      if !node.xpath("//marc:datafield[@tag='#{new_tag}']", NAMESPACE).empty?
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
          end
        end
      end
    end

    def repair_leader
      leader = node.xpath("//marc:leader", NAMESPACE).first
      leader.content = leader.content.gsub(/#/," ")
    end

  end
end


