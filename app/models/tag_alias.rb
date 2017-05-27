class TagAlias < ActiveRecord::Base
  belongs_to :tag, :foreign_key => "alias_id"
  before_create :normalize
  before_create :validate_uniqueness
  after_destroy :expire_tag_cache_after_deletion

  # Maps tags to their preferred names. Returns an array of strings.
  #
  # === Parameters
  # * :tags<Array<String>>:: list of tags to transform.
  def self.to_aliased(tags)
    Array(tags).reduce([]) do |aliased_tags, tag_name|
      aliased_tags << to_aliased_helper(tag_name)
    end
  end

  def self.to_aliased_helper(tag_name)
    # TODO: add memcached support
    tag = joins(:tag).select("tags.name").where(:name => tag_name, :is_pending => false).first
    tag ? tag.name : tag_name
  end

  # Destroys the alias and sends a message to the alias's creator.
  def destroy_and_notify(current_user, reason)
    if creator_id && creator_id != current_user.id
      msg = "A tag alias you submitted (#{name} → #{alias_name}) was deleted for the following reason: #{reason}."
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
      errors.add(:base, "#{name} is already aliased to something")
      throw :abort
    end

    if self.class.exists?(["alias_id = (select id from tags where name = ?)", name])
      errors.add(:base, "#{name} is already aliased to something")
      throw :abort
    end

    if self.class.exists?(["name = ?", alias_name])
      errors.add(:base, "#{alias_name} is already aliased to something")
      throw :abort
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
    update_columns :is_pending => false

    Post.available.has_all_tags(name).find_each do |post|
      post.reload
      post.update_attributes(:tags => post.cached_tags, :updater_user_id => user_id, :updater_ip_addr => ip_addr)
    end

    Moebooru::CacheHelper.increment_version("tag")
  end

  def expire_tag_cache_after_deletion
    Moebooru::CacheHelper.increment_version("tag")
  end

  def api_attributes
    {
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
    api_attributes.as_json(*args)
  end
end
