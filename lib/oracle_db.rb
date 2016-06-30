require 'rubygems'
require 'oci8'
require 'nokogiri'
require 'pry'

# Connector for OracleDB; credentials have to be in the enviroment
class OracleDB
  attr_accessor :connection
  def initialize
    OCI8::BindType::Mapping[:number] = OCI8::BindType::Integer
    ENV["NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P9"]
  end
  def connection
    OCI8.new(ENV['ORACLE_USER'], ENV['ORACLE_PASSWORD'], ENV['ORACLE_HOST'])
  end
end

