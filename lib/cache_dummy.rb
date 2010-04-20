class MemCache
  def flush_all
  end
end

module Cache
  def self.get(key, expiry = 0)
    if block_given? then
      yield
    end
  end
end

