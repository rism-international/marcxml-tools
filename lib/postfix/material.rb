#!/usr/bin/env ruby
require 'rubygems'
require 'pry'
require 'active_record'
require 'activerecord-import'
require 'sqlite3'
require "awesome_print"
Dir['/home/stephan/projects/marcxml-tools/lib/*.rb'].each do |file| 
  require file 
end

#connection = OracleDB.new.connection

ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: 'materials.db'
)
=begin
ActiveRecord::Schema.define do
    create_table :materials, force: true do |t|
      t.string :_001
      t.integer :isn
      t.string :layer
      t.string :_260a
      t.string :_260c
      t.string :_300a
      t.string :_300c
      t.text :_500a
      t.string :_590a
      t.string :_590b
      t.string :_592a
      t.string :_593a
      t.string :_7000
      t.string :similarity
      t.string :difference
    end
end
=end
class Material < ActiveRecord::Base
  def size
    self.attributes.map{|e, v| v }.compact.size - 2
  end

  def compare(m2)
    blist = %w(454002500)
    result = 0
    result += 2 if self._260a == m2._260a && self._260a
    result += 2 if self._260c == m2._260c && self._260c
    result += 2 if self._300a == m2._300a && self._300a
    result += 2 if self._300c == m2._300c && self._300c
    
    if self._500a
      db_text = m2._500a ? m2._500a : ""
      if self._500a == db_text
        result += 2
      elsif self._500a.start_with?(db_text)
        result += 1
      end
    end
    if self._590a
      db_text = m2._590a ? m2._590a : ""
      if self._590a == db_text
        result += 2
      elsif self._590a.start_with?(db_text)
        result += 1
      end
    end
    if self._590b
      db_text = m2._590b ? m2._590b : ""
      if self._590b == db_text
        result += 2
      elsif self._590b.start_with?(db_text)
        result += 1
      end
    end
    result += 2 if self._592a == m2._592a && self._592a
    result += 2 if self._593a == m2._593a && self._593a
    result += 2 if self._7000 == m2._7000 && self._7000
    binding.pry if blist.include?(self._001)
    return result
  end

  def find_best(coll)
    result = {}
    coll.each do |m2|
      result[m2] = self.compare(m2)
    end
    rating_list = result.sort_by {|_key, value| value}.reverse
    self.difference = rating_list.size == 1 ? -1 : rating_list.first[1] - rating_list[1][1] rescue 99
    self.similarity = rating_list.first[1] rescue -1
    rating_list.first.first rescue nil
  end
end
