require 'yaml'
require 'sqlite3'
require 'pry'
y = YAML.load_file('20170201-sources-bemint.yml')
db = SQLite3::Database.open "test.db"

y.each do |e|
  e[1].each do |l|
    l.each do |k,v|
      begin 
        db.execute("insert into bemint(isn, bemtext, bemind) values (?,?,?)", [e.first, v, k])
        puts "#{e.first rescue ''} #{v rescue ''} #{k rescue ''}" 
      rescue 
        puts "ALERT: #{e.first rescue ''} #{v rescue ''} #{k rescue ''}" 
      end
    end
  end
end
