module TagApiMethods
  def self.included(m)
    m.extend(ClassMethods)
  end

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

  module ClassMethods
    # Create a compact list of all active tags, sorted by post_count.
    #
    # "1:tagme 2:fixme 3:fixed "
    #
    # The string is guaranteed to have a trailing space, so ":tagme " can be used to match
    # a whole tag.
    #
    # This is returned as a preencoded JSON string, so the entire block can be cached.
    def get_json_summary
      summary_version = Tag.get_summary_version
      key = "tag_summary/#{summary_version}"

      data = Cache.get(key, 3600) do
        data = Tag.get_json_summary_no_cache
        data.to_json
      end

      return data
    end

    def get_json_summary_no_cache
      version = Tag.get_summary_version

      tags = Tag.find(:all, :conditions => "post_count > 0", :order => "post_count DESC", :select => "tag_type, name")
      tags_with_type = tags.map { |tag| "%i:%s" % [tag.tag_type, tag.name] }
      tags_string = tags_with_type.join(" ") + " "
      return { :version => version, :data => tags_string }
    end

    # Return the cache version of the summary.
    def get_summary_version
      return Cache.get("$tag_version") do 0 end
    end
  end
end
