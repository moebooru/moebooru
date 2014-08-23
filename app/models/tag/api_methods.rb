module Tag::ApiMethods
  def self.included(m)
    m.extend(ClassMethods)
  end

  def api_attributes
    {
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

  def as_json(*args)
    api_attributes.as_json(*args)
  end

  module ClassMethods
    # Create a compact list of all active tags, sorted by post_count.
    #
    # "1`tagme` 2`fixme` 3`fixed`alias` "
    #
    # Each tag is bounded by backticks, so "`tagme`" can be used to match a whole tag.
    #
    # This is returned as a preencoded JSON string, so the entire block can be cached.
    def get_json_summary
      summary_version = Tag.get_summary_version
      key = "tag_summary/#{summary_version}"

      data = Rails.cache.fetch(key, :expires_in => 1.hour) do
        data = Tag.get_json_summary_no_cache
        data.to_json
      end

      data
    end

    def get_json_summary_no_cache
      version = Tag.get_summary_version

      tags = select_all_sql("""
        SELECT t.id, t.name, t.tag_type, ta.name AS alias
        FROM tags t LEFT JOIN tag_aliases ta ON (t.id = ta.alias_id AND NOT ta.is_pending)
        WHERE t.post_count > 0
        ORDER BY t.id, ta.name""")

      tags_with_type = []
      current_tag = ""
      last_tag_id = nil
      tags.each do |tag|
        id = tag["id"]
        if id != last_tag_id then
          if !last_tag_id.nil? then
            tags_with_type << current_tag
          end

          last_tag_id = id
          current_tag = "%s`%s`" % [tag["tag_type"], tag["name"]]
        end

        if !tag["alias"].nil? then
          current_tag << tag["alias"] + "`"
        end
      end
      if !last_tag_id.nil? then
        tags_with_type << current_tag
      end

      tags_string = tags_with_type.join(" ") + " "
      { :version => version, :data => tags_string }
    end

    # Return the cache version of the summary.
    def get_summary_version
      Rails.cache.fetch("$tag_version") { 0 }
    end
  end
end
