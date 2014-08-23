module Tag::TypeMethods
  module ClassMethods
    attr_accessor :type_map

    # Find the type name for a type value.
    #
    # === Parameters
    # * :type_value<Integer>:: The tag type value to search for
    def type_name_from_value(type_value)
      type_map[type_value]
    end

    def type_name_helper(tag_name) # :nodoc:
      tag = Tag.where(:name => tag_name).select(:tag_type).first

      if tag.nil?
        "general"
      else
        type_map[tag.tag_type]
      end
    end

    # Find the tag type name of a tag.
    #
    # === Parameters
    # * :tag_name<String>:: The tag name to search for
    def type_name(tag_name)
      Rails.cache.fetch({ :tag_type => tag_name }, :expires_in => 1.day) do
        type_name_helper(tag_name.gsub(/\s/, "_"))
      end
    end

    # Get all tag types for the given list of posts.
    def batch_get_tag_types_for_posts(posts)
      post_tags = Set.new
      posts.each do |post|
        post_tags += post.cached_tags.split
      end
      batch_get_tag_types(post_tags)
    end

    # Get all tag types for the given tags.
    def batch_get_tag_types(post_tags)
      post_tags = Set.new(post_tags)

      post_tags_key = post_tags.each_with_object([]) { |t, k| k << { :tag_type => t } }
      # Without this, the following splat will eat the last argument because
      # it'll be considered an option instead of key (being a hash).
      post_tags_key << {}

      results = {}
      Rails.cache.read_multi(*post_tags_key).each do |cache_key, value|
        # The if cache_key is required since there's small chance read_multi
        # returning nil key on certain key names.
        results[cache_key[:tag_type]] = value if cache_key
      end
      (post_tags - results.keys).each do |tag|
        results[tag] = type_name(tag)
      end
      results
    end

    # Given an array of tags, remove tags to reduce the joined length to <= max_len.
    def compact_tags(tags, max_len)
      return tags if tags.length < max_len

      split_tags = tags.split(/ /)

      # Put long tags first, so we don't remove every tag because of one very long one.
      split_tags.sort! do |a, b| b.length <=> a.length end

      # Tag types that we're allowed to remove:
      length = tags.length
      split_tags.each_index do |i|
        length -= split_tags[i].length + 1
        split_tags[i] = nil
        break if length <= max_len
      end

      split_tags.compact!
      split_tags.sort!
      split_tags.join(" ")
    end

    def tag_list_order(tag_type)
      case tag_type
        when "artist" then 0
        when "circle" then 1
        when "copyright" then 2
        when "character" then 3
        when "general" then 5
        when "faults" then 6
        else 4
      end
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
    m.versioned :tag_type
    m.versioned :is_ambiguous, :default => false

    m.versioning_group_by :action => "edit"

    # This maps ids to names
    m.type_map = CONFIG["tag_types"].keys.select { |x| x =~ /^[A-Z]/ }.inject({}) { |all, x| all[CONFIG["tag_types"][x]] = x.downcase; all }
  end

  def type_name
    self.class.type_name_from_value(tag_type)
  end

  def pretty_type_name
    type_name.capitalize
  end
end
