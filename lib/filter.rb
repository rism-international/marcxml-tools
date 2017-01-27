# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'

# Parent class for modifying Marcxml

module Marcxml
  class Filter
    include Logging
    @connected_records = []
    @config = {}
    @result_records = []
    @xor = false
    @connected = false
    class << self
      attr_accessor :connected_records, :result_records, :config, :xor, :connected
    end


    attr_accessor :node, :namespace, :result
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      @result = []
    end

    def match?
      id=node.xpath('//marc:controlfield[@tag="001"]', NAMESPACE)[0].content rescue nil
      return false unless id
      Filter.config.each do |k,v|
        if k.include?('$')
          df=k.split("$")[0]
          sf=k.split("$")[1]
          res=node.xpath('//marc:datafield[@tag="'+df+'"]/marc:subfield[@code="'+sf+'"]', NAMESPACE)
        else
          res=node.xpath('//marc:controlfield[@tag="'+k+'"]', NAMESPACE)
        end
        res.each do |node|
          if v.class==String
            if node.content =~ /#{v}/
              result<<true
              break
            end
          elsif v.class==Array
            v.each do |entry|
              if node.content =~ /#{entry}/
                result<<true
              end
            end
          end
        end
      end
      if Filter.xor
        if result.include?(true)
          if Filter.connected
            tag, code = Filter.connected.split("$")
            node.xpath('//marc:datafield[@tag="' + tag + '"]/marc:subfield[@code="' + code + '"]', NAMESPACE).each do |e|
              Filter.connected_records << e.content
            end
          end
          Filter.result_records << id
          return true
        end
      else
        if result.size==Filter.config.values.flatten.size
          if Filter.connected
            tag, code = Filter.connected.split("$")
            node.xpath('//marc:datafield[@tag="' + tag + '"]/marc:subfield[@code="' + code + '"]', NAMESPACE).each do |e|
              Filter.connected_records << e.content
            end
          end
          Filter.result_records << id
          return true
        end
      end
      return false
    end
  end
end


