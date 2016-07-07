require 'rubygems'
require 'oci8'
require 'nokogiri'
require 'pry'
require 'colorize'

# Connector for OracleDB; credentials have to be in the enviroment
class OracleDB
  attr_accessor :connection
  def initialize
    begin
      OCI8::BindType::Mapping[:number] = OCI8::BindType::Integer
    rescue
      puts "Oracle Access is not configured through enviroment!".red
    end
  end
  def connection
    begin
      OCI8.new(ENV['ORACLE_USER'], ENV['ORACLE_PASSWORD'], ENV['ORACLE_HOST'])
    rescue
      puts "Oracle Access is not configured through enviroment!".red
      puts "Please set the values in your enviroment before starting, e.g.:".red
      puts "export LD_LIBRARY_PATH=/usr/lib/oracle/10.2.0.4/client64/lib; export NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1; export ORACLE_USER=user; export ORACLE_PASSWORD=password; export ORACLE_HOST='example.com:1521/orcl'".red
    end
  end
end

