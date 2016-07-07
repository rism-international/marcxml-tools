# encoding: UTF-8
require 'rubygems'
require 'nokogiri'
require 'rbconfig'
require 'axlsx'
require_relative 'logging'
require_relative 'marc_string'

module Marcxml
  class Result
    attr_accessor :total, :header
    def initialize
      @total = []
    end

    def sorted_by(options)
      idx = options[:index]
      header = self.to_header
      h = []
      total.each do |e|
        h << e.values_at(*header)      
      end
      if options[:reverse]
        return h.sort_by{|p| p[idx]}.reverse
      else
        return h.sort_by{|p| p[idx]}
      end
    end

    def to_xls(options)
      colors = %w(000000 FF0000 00FF00 0000FF FFFF00 00FFFF FF00FF C0C0C0 808080 800000 808000 008000 800080 008080 000080)
      header = self.to_header
      p = Axlsx::Package.new 
      wb = p.workbook
      item_style = wb.styles.add_style :b => false, :height => 20, :sz => 12,  :font_name => 'Arial', :alignment => { :horizontal => :left, :vertical => :center, :wrap_text => false }
      wb.add_worksheet(:name => "Pie Chart") do |sheet|
        sheet.add_row header, :style => item_style
          #total.each do |e|
        sorted_by(options).each do |row|
            #sheet.add_row(e.values_at(*header))
          sheet.add_row(row, :style => item_style)
        end
        sheet.add_chart(Axlsx::Pie3DChart) do | chart |
          chart.title = sheet["A1"]
          chart.add_series :data => sheet["B2:B10"], :labels => sheet["A2:A10"], :colors => colors[1..9]
            chart.start_at 8, 3
            chart.end_at 15, 18
        end
      end
      p.serialize(options[:ofile])
    end

    def to_header
      res = []
      total.each do |e|
        e.keys.each do |column|
          if !res.include?(column)
            res << column
          end
        end
      end
      return res
    end

    def get_row(v)
      total.each do |e|
        return e if e.values.include?(v)
      end
      return false
    end

    def to_s(sep="\t")
      StringIO.open do |s|
        header = self.to_header
        print header.join(sep)
        total.each do |e|
          print("\n#{e.values_at(*header).join(sep)}")
        end
        return s.string
      end
    end
      
    def to_csv(out_file)
      header = self.to_header
      require 'csv'
      CSV.open(out_file, "w", {:col_sep => ";"}) do |csv|
        csv << header
        total.each do |e|
          csv << e.values_at(*header)
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
        content = subfield.content
        row = result.get_row(content)
        if !row
          h = Hash.new(0)
          h[marc_tag] = content
          h[get_record_type] += 1
          result.total << h
        else
          row[get_record_type] += 1
        end
      end
    end
  end
end

