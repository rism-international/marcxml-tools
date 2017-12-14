require 'pry'
a = {1 => {2 => [3, {4 => 5}] }}

def contains(str, coll)
  raise(TypeError, "object is not a collection") unless coll.class < Enumerable
  coll.each do |e|
      unless e.class < Enumerable
        return e == str ? true : false
      else
        return true if contains(str, e)
      end
    end
  return false
end

puts contains(7, a)


