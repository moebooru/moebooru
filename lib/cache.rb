module Cache
  def expire(options = {})
    if CONFIG["enable_caching"]
      tags = options[:tags]
      cache_version = Cache.get("$cache_version").to_i

      Cache.put("$cache_version", cache_version + 1)

      if tags
        tags.scan(/\S+/).each do |x|
          key = "tag:#{x}"
          key_version = Cache.get(key).to_i
          Cache.put(key, key_version + 1)
        end
      end
    end
  end
  
  def incr(key)
    if CONFIG["enable_caching"]
      val = Cache.get(key)
      Cache.put(key, val.to_i + 1)
    end
  end
  
  module_function :expire
  module_function :incr
end
