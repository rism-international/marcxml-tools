#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'nokogiri'
require 'trollop'
require 'ruby-progressbar'
require 'rbconfig'
require 'zip'

OS=RbConfig::CONFIG['host_os']
NAMESPACE={'marc' => "http://www.loc.gov/MARC21/slim"}
SCHEMA_FILE="MARC21slim.xsd"

#Hack for resolving leader problems: sed -i '/<leader>00000cdd#a2200000###4500<\/leader>/c\<leader>00000ccm a2200000   4500<\/leader>' 050000.xml

#OPTIONS
opts = Trollop::options do
  version "RISM validator 1.0"
  banner <<-EOS
This utility program validates MARCXML

Usage:
   record_search [options]
where [options] are:
  EOS

  opt :infile, "Input-Filename", :type => :string
end

Trollop::die :infile, "must exist; you can download it from https://opac.rism.info/fileadmin/user_upload/lod/update/rismAllMARCXML.zip" if !opts[:infile]
source_file=opts[:infile]
resfile=opts[:outfile]
xsd = Nokogiri::XML::Schema(File.read(SCHEMA_FILE))

xsd.validate(source_file).each do |error|
      puts "#{error.line} :: #{error.message}"
      break
end
