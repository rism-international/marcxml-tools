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

end
