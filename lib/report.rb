# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require_relative 'logging'
require_relative 'marc_string'

class Result
  attr_accessor :total
  def initialize
    @total = []
  end
  
  def has_value?(tag, value)
    total.map{ |e| e[tag] }.include?(value)
  end

  def values_of(tag, value)
    total.select{ |e| e if e[tag]==value }[0]
  end

  def to_s
    StringIO.open do |s|
      total.each do |e|
        e.each do |k,v|
          print "#{k}: #{v}\t"
        end
      print "\n"
      end
      return s.string
    end
  end
    
  def to_csv(out_file)
    require 'csv'
    CSV.open(out_file, "w", {:col_sep => ";"}) do |csv|
      keys = total.first.keys
      csv << keys
      total.each do |e|
        csv << e.values_at(*keys) 
      end
    end
  end
end


class Report
  include Logging
  attr_accessor :node, :namespace, :result
  def initialize(node, result, namespace={'marc' => "http://www.loc.gov/MARC21/slim"})
    @namespace = namespace
    @node = node
    @result = result
  end

  def get_record_type
    leader=node.xpath("//marc:leader", NAMESPACE)[0]
    return leader.content.marc_record_type 
  end

  def generate_from_tag(marc_tag)
    tag, code = marc_tag.split("$")
    subfields = node.xpath("//marc:datafield[@tag='#{tag}']/marc:subfield[@code='#{code}']", NAMESPACE)
    subfields.each do |subfield|
      #country = subfield.content.gsub(/\-.+$/, "")
      country = subfield.content
      if !result.has_value?(marc_tag, country)
        res = { marc_tag => country, :print => 0, :manuscript => 0, :mixt => 0 }
        res[get_record_type] += 1
        result.total << res
      else
        res = result.values_of(marc_tag, country)
        result.total.delete(res)
        res[get_record_type] += 1
        result.total << res
      end
    end
  end
end


