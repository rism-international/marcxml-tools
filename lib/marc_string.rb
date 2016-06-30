class String
  def is_tag?
    self =~ /^[0-9]{3}$/
  end

  def is_subfield?
    self =~ /^[a-z0-9]{1}$/
  end

  def is_tag_with_subfield?
     self =~ /^[0-9]{3}\$[a-z0-9]{1}$/
  end
 
  def is_content?
    return false if self.is_tag?
    return false if self.is_subfield?
    return false if self.is_tag_with_subfield?
    return true
  end

  def ends_with_url?
    self =~ /.+:\s{1}(http|https):\/\/\S+$/
  end

  def marc_record_type
    case self[6]
    when "c"
      return :print
    when "d"
      return :manuscript
    when "p"
      return :mixt
    end
  end
end


