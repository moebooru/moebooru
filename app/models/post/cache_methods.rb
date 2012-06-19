module PostCacheMethods
  def self.included(m)
    m.after_save :expire_cache
    m.after_destroy :expire_cache
  end

  def expire_cache
    # Have to call this twice in order to expire tags that may have been removed
    Rails.cache.expire(:tags => old_cached_tags) if old_cached_tags
    Rails.cache.expire(:tags => cached_tags)
  end
end
