module ActiveSupport
  module Cache
    module StoreExt
      def expire(options = {})
        write('$cache_version', Time.now.to_i)
      end

      def expire_tag_version
        # $tag_version is bumped when the type of a tag is changed in Tags, if
        # a new tag is created, or if a tag's post_count becomes nonzero.
        incr("$tag_version")
      end

      def incr(key)
          val = read(key)
          write(key, val.to_i + 1)
      end
    end
    Store.send :include, StoreExt
    # DalliStore doesn't inherit Store, therefore it directly injected
    DalliStore.send :include, StoreExt if defined? DalliStore
  end
end
