if CONFIG["enable_caching"]
  require 'memcache'
  require 'memcache_util'
  require 'cache'
  require 'memcache_util_store'
else
  require 'cache_dummy'
end
  
  CACHE = MemCache.new :c_threshold => 10_000, :compression => true, :debug => false, :namespace => CONFIG["app_name"], :readonly => false, :urlencode => false
  CACHE.servers = CONFIG["memcache_servers"]
  begin
    CACHE.flush_all
  rescue MemCache::MemCacheError
  end
