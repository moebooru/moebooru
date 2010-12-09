module TagTypeMethods
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
      tag = Tag.find(:first, :conditions => ["name = ?", tag_name], :select => "tag_type")

      if tag == nil
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
      tag_name = tag_name.gsub(/\s/, "_")
      
      if CONFIG["enable_caching"]
        return Cache.get("tag_type:#{tag_name}", 1.day) do
          type_name_helper(tag_name)
        end
      else
        type_name_helper(tag_name)
      end
    end

    # Get all tag types for the given list of posts.
    def batch_get_tag_types_for_posts(posts)
      post_tags = Set.new
      posts.each { |post|
        post_tags.merge(post.cached_tags.split.map { |p| p} )
      }
      return batch_get_tag_types(post_tags)
    end

    # Get all tag types for the given tags.
    def batch_get_tag_types(post_tags)
      post_tags = post_tags.map { |p| "tag_type:#{p}" }
      post_tags = Set.new(post_tags)

      # Memcache is dropping our connection if we make too make requests at once.  Request
      # tag types max_tags_per_query at a time.
      results = {}
      got_keys = Set.new
      tags_to_query = post_tags.to_a
      max_tags_per_query = 1000
      start_at = 0
      begin
        while start_at < tags_to_query.length do
          tag_types = CACHE.get_multi(tags_to_query.slice(start_at, max_tags_per_query))
          start_at += max_tags_per_query

          # Strip off "tag_type:" from the result keys.
          tag_types.each { |key, value| results[key[9..-1]] = value }

          # Find which keys we didn't get from cache and fill them in.  This will also
          # populate the cache.
          got_keys.merge(tag_types.keys)
        end
      rescue MemCache::MemCacheError
        tag_types = {}
      rescue NameError => e
        # get_multi in activesupport-2.2.2 has a bug in exception handling; it tries to
        # access "server" out of scope, causing it to raise NameError.  This happens if
        # the above EPIPE error triggers.  If this happens despite running smaller queries,
        # log it and reste the memcache connection.
        logger.warn("Unexpected MemCache error: #{e}")
        CACHE.reset
        tag_types = {}
      end

      needed_keys = post_tags - got_keys
      needed_keys.each { |key|
        key =~ /tag_type:(.*)/
        tag_name = $1
        results[tag_name] = type_name(tag_name)
      }

      return results
    end

    # Given an array of tags, remove tags to reduce the joined length to <= max_len.
    def compact_tags(tags, max_len)
      return tags if tags.length < max_len

      split_tags = tags.split(/ /)

      # Put long tags first, so we don't remove every tag because of one very long one.
      split_tags.sort! do |a,b| b.length <=> a.length end

      # Tag types that we're allowed to remove:
      length = tags.length
      split_tags.each_index do |i|
        length -= split_tags[i].length + 1
        split_tags[i] = nil
        break if length <= max_len
      end

      split_tags.compact!
      split_tags.sort!
      return split_tags.join(" ")
    end

    def tag_list_order(tag_type)
      case tag_type
      when "artist": 0
      when "circle": 1
      when "copyright": 2
      when "character": 3
      when "general": 5
      when "faults": 6
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
    m.type_map = CONFIG["tag_types"].keys.select {|x| x =~ /^[A-Z]/}.inject({}) {|all, x| all[CONFIG["tag_types"][x]] = x.downcase; all}    
  end

  def type_name
    self.class.type_name_from_value(tag_type)
  end

  def pretty_type_name
    type_name.capitalize
  end
end
