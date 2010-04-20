module TagApiMethods
  def api_attributes
    return {
      :id => id, 
      :name => name, 
      :count => post_count, 
      :type => tag_type, 
      :ambiguous => is_ambiguous
    }
  end
  
  def to_xml(options = {})
    api_attributes.to_xml(options.merge(:root => "tag"))
  end

  def to_json(*args)
    api_attributes.to_json(*args)
  end
end
