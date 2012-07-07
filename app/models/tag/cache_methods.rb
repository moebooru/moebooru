module TagCacheMethods
  def self.included(m)
    m.after_save :update_cache
    m.after_create :update_cache_on_create
  end

  def update_cache
    Rails.cache.write({ :type => :tag_type, :name => name }, self.class.type_name_from_value(tag_type))

    # Expire the tag cache if a tag's type changes.
    if self.tag_type != self.tag_type_was then
      Rails.cache.expire_tag_version
    end
  end

  # Expire the tag cache when a new tag is created.
  def update_cache_on_create
    Rails.cache.expire_tag_version
  end
end

