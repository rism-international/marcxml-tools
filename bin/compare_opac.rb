require 'yaml'
opac = YAML.load_file("../export/opac/#{ARGV[0]}_analyze.txt")
old = YAML.load_file("../input/#{ARGV[0]}_analyze.txt")

puts ARGV[0]
puts "TAG\t|\tOLD\t|\tNEW\t|\t  "
puts "--------------------------------"

old.each do |k,v|
  old_value = v.split(" ").first.to_i / 1000
  new_value = (opac[k].split(" ").first rescue "0").to_i / 1000
  puts "#{k}\t|\t#{old_value}\t|\t#{new_value}\t|\t#{old_value > new_value ? "!!" : "--"}    "
end
