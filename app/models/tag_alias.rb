class TagAlias < ActiveRecord::Base
  before_create :normalize
  before_create :validate_uniqueness

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
    tag = Tag.find_or_create_by_name(name)
    self.alias_id = tag.id
  end
  
  def alias_name
    Tag.find(alias_id).name
  end

  def approve(user_id, ip_addr)
    execute_sql("UPDATE tag_aliases SET is_pending = FALSE WHERE id = ?", id)
    
    Post.find(:all, :conditions => ["id IN (SELECT pt.post_id FROM posts_tags pt WHERE pt.tag_id = (SELECT id FROM tags WHERE name = ?))", name]).each do |post|
      post.reload
      post.update_attributes(:tags => post.cached_tags, :updater_user_id => user_id, :updater_ip_addr => ip_addr)
    end
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
    api_attributes.to_xml(options.merge(:root => "tag_alias"))
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end
end
