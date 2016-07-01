require 'rubygems'
require 'oci8'
require 'nokogiri'
require 'pry'

# Connector for OracleDB; credentials have to be in the enviroment
class OracleDB
  attr_accessor :connection
  def initialize
    begin
      OCI8::BindType::Mapping[:number] = OCI8::BindType::Integer
      ENV["NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P9"]
    rescue
      puts "Oracle Access is not configured through enviroment!"
    end
  end
  def connection
    begin
      OCI8.new(ENV['ORACLE_USER'], ENV['ORACLE_PASSWORD'], ENV['ORACLE_HOST'])
    rescue
      puts "Oracle Access is not configured through enviroment!"
      return -1
    end
  end
end

