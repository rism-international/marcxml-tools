module Marcxml
  class ApplicationHelper
    attr_accessor :total
    def self.total(source_file)
      os = RbConfig::CONFIG['host_os']
      total = 0
      if os =~ /linux/
        total =`grep -c "<marc:record" #{source_file}`.to_i
        if total == 0
          total =`grep -c "<record" #{source_file}`.to_i
        end
      else
        file_size=File.size(source_file)
        if file_size > 800000000
          approx=3700
          total=(file_size / approx).floor
        else
          File.open( source_file, 'r:BINARY' ) do |io|
            io.each do |line| 
              total+=1 if line =~ /marc:record|record>/
            end
          end
        end
      end
      return total
    end

    def self.normalize_role(str)
      return str.gsub(/[\[\]]/, "").gsub(/\s+\(.*$/, "").strip
    end
  end
end
