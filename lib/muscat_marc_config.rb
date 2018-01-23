# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require 'yaml'

module Marcxml
  # Parent class for modifying Marcxml
  class MuscatMarcConfig
    class << self
      attr_accessor :config
    end

    attr_accessor :config, :model
    def initialize(model)
      @model = model
      @config = YAML.load_file("conf/tag_config_#{model.downcase.to_s}.yml")
    end

    def tags_with_subtags
      res = {}
      @config[:tags].each do |k,v|
        res[k] = v[:fields].map{|e| e[0]}
      end
      return res
    end
    
  end
end


