module Post::CacheMethods
  def self.included(m)
    m.after_save :expire_cache
    m.after_destroy :expire_cache
  end

  def expire_cache
    # FIXME: this removes too many caches.
    # Reference: https://github.com/moebooru/moebooru/commit/896dbff
    Moebooru::CacheHelper.increment_version
  end
end
