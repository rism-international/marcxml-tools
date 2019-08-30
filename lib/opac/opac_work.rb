# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative '../logging'
require_relative '../transformator'

module Marcxml
  class OpacWork < Transformator
    include Logging
    attr_accessor :node, :namespace, :methods
    def initialize(node, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
      @namespace = namespace
      @node = node
      #@methods = [:add_isil, :change_media, :change_ks_relator, :repair_leader, :add_short_title, :map]
      @methods = [:insert_leader, :map]
    end

  end

end
