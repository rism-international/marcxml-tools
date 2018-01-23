# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'

module Marcxml
  # Parent class for modifying Marcxml
  class MuscatMarcConfig
    class << self
      attr_accessor :config
    end

    attr_accessor :config, :model
    def initialize(model)
      @model = model
      @config = Yaml.load("../conf/tag_config_source.yml")
    end
    
  end
end


