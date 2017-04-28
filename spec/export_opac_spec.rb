require 'yaml'
require 'pry'

describe "Sources new export compared with last export" do
  old_file = YAML.load_file("export/opac/archive/sources_analyze.txt")
  new_file = YAML.load_file("export/opac/sources_analyze.txt")
  old_file.each do |k,v|
    next if k == '*MAX'
    it "sources new size of #{k} should be >= than with last export" do
      old_value = v.gsub(/\s+.*$/, "").to_i
      new_value = new_file[k].gsub(/\s+.*$/, "").to_i
      expect(old_value).to be <= new_value
    end
  end
end

describe "People new export compared with last export" do
  old_file = YAML.load_file("export/opac/archive/people_analyze.txt")
  new_file = YAML.load_file("export/opac/people_analyze.txt")
  old_file.each do |k,v|
    next if k == '*MAX'
    it "people new size of #{k} should be >= than with last export" do
      old_value = v.gsub(/\s+.*$/, "").to_i
      new_value = new_file[k].gsub(/\s+.*$/, "").to_i
      expect(old_value).to be <= new_value
    end
  end

end

describe "Institutions new export compared with last export" do
  old_file = YAML.load_file("export/opac/archive/institutions_analyze.txt")
  new_file = YAML.load_file("export/opac/institutions_analyze.txt")
  old_file.each do |k,v|
    next if k == '*MAX'
    it "institutions new size of #{k} should be >= than with last export" do
      old_value = v.gsub(/\s+.*$/, "").to_i
      new_value = new_file[k].gsub(/\s+.*$/, "").to_i
      expect(old_value).to be <= new_value
    end
  end

end

describe "Catalogue new export compared with last export" do
  old_file = YAML.load_file("export/opac/archive/catalogues_analyze.txt")
  new_file = YAML.load_file("export/opac/catalogues_analyze.txt")
  old_file.each do |k,v|
    next if k == '*MAX'
    it "catalogue new size of #{k} should be >= than with last export" do
      old_value = v.gsub(/\s+.*$/, "").to_i
      new_value = new_file[k].gsub(/\s+.*$/, "").to_i
      expect(old_value).to be <= new_value
    end
  end

end
