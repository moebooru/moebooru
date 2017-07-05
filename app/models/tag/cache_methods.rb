module Tag::CacheMethods
  def self.included(m)
    m.after_save :update_cache
    m.after_create :update_cache_on_create
  end

  def update_cache
    Rails.cache.write({ :tag_type => name }, self.class.type_name_from_value(tag_type))

    # Expire the tag cache if a tag's type changes.
    if saved_change_to_tag_type?
      Moebooru::CacheHelper.increment_version("tag")
    end
  end

  # Expire the tag cache when a new tag is created.
  def update_cache_on_create
    Moebooru::CacheHelper.increment_version("tag")
  end
end
