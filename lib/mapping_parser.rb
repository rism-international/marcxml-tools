#require 'marc_string'
#TODO prpbably for creating mapping class, unused now
class MappingParser
  attr_accessor :config
  def initialize(config)
    @config = config
  end

  def starter
    hash.each do |k,v|
      if !v && k.is_tag_with_subfield?
            remove_subfield << k
      elsif !v && k.is_tag?
            remove_datafield << k
          # Rename datafield
      elsif k.is_tag? && v.is_tag?
            rename_datafield.merge({k => v})
          # Rename subfield
      elsif k.is_tag_with_subfield? && v.is_subfield?
            tag=k.split("$")[0]
            old_sf=k.split("$")[1]
            new_sf=v
            tr.rename_subfield_code(tag, old_sf, new_sf)
          # Move subfield
      elsif k.is_tag_with_subfield? && v.is_tag?
            tr.move_subfield_to_tag(k, v)
      end
    end

  end

end
