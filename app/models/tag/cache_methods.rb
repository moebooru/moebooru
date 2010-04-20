module TagCacheMethods
  def self.included(m)
    m.after_save :update_cache
  end

  def update_cache
    Cache.put("tag_type:#{name}", self.class.type_name_from_value(tag_type))
  end
end

