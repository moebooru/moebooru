class TagAlias < ActiveRecord::Base
  before_create :normalize
  before_create :validate_uniqueness
  after_destroy :expire_tag_cache_after_deletion

  # Maps tags to their preferred names. Returns an array of strings.
  #
  # === Parameters
  # * :tags<Array<String>>:: list of tags to transform.
  def self.to_aliased(tags)
    Array(tags).inject([]) do |aliased_tags, tag_name|
      aliased_tags << to_aliased_helper(tag_name)
    end
  end
  
  def self.to_aliased_helper(tag_name)
    # TODO: add memcached support
    tag = find(:first, :select => "tags.name AS name", :joins => "JOIN tags ON tags.id = tag_aliases.alias_id", :conditions => ["tag_aliases.name = ? AND tag_aliases.is_pending = FALSE", tag_name])
    tag ? tag.name : tag_name    
  end
  
  # Destroys the alias and sends a message to the alias's creator.
  def destroy_and_notify(current_user, reason)
    if creator_id && creator_id != current_user.id
      msg = "A tag alias you submitted (#{name} &rarr; #{alias_name}) was deleted for the following reason: #{reason}."
      Dmail.create(:from_id => current_user.id, :to_id => creator_id, :title => "One of your tag aliases was deleted", :body => msg)
    end
    
    destroy
  end

  # Strips out any illegal characters and makes sure the name is lowercase.
  def normalize
    self.name = name.downcase.gsub(/ /, "_").gsub(/^[-~]+/, "")
  end

  # Makes sure the alias does not conflict with any other aliases.
  def validate_uniqueness
    if self.class.exists?(["name = ?", name])
      errors.add_to_base("#{name} is already aliased to something")
      return false
    end
    
    if self.class.exists?(["alias_id = (select id from tags where name = ?)", name])
      errors.add_to_base("#{name} is already aliased to something")
      return false
    end
    
    if self.class.exists?(["name = ?", alias_name])
      errors.add_to_base("#{alias_name} is already aliased to something")
      return false
    end
  end

  def alias=(name)
    alias_tag = Tag.find_or_create_by_name(name)
    tag = Tag.find_or_create_by_name(self.name)
    
    if alias_tag.tag_type != tag.tag_type
      alias_tag.update_attribute(:tag_type, tag.tag_type)
    end
    
    self.alias_id = alias_tag.id
  end
  
  def alias_name
    Tag.find(alias_id).name
  end
  
  def alias_tag
    Tag.find_or_create_by_name(name)
  end

  def approve(user_id, ip_addr)
    execute_sql("UPDATE tag_aliases SET is_pending = FALSE WHERE id = ?", id)
    
    Post.find(:all, :conditions => ["tags_index @@ to_tsquery('danbooru', ?)", QueryParser.generate_sql_escape(name)]).each do |post|
      post.reload
      post.update_attributes(:tags => post.cached_tags, :updater_user_id => user_id, :updater_ip_addr => ip_addr)
    end

    Rails.cache.expire_tag_version
  end
  
  def expire_tag_cache_after_deletion
    Rails.cache.expire_tag_version
  end

  def api_attributes
    return {
     :id => id, 
     :name => name, 
     :alias_id => alias_id, 
     :pending => is_pending 
    }
  end

  def to_xml(options = {})
    api_attributes.to_xml(options.reverse_merge(:root => "tag_alias"))
  end

  def as_json(*args)
    return api_attributes.as_json(*args)
  end
end
