module Moebooru
  module CacheHelper
    def expire(options = {})
      Rails.cache.write("$cache_version", Time.now.to_i)
    end

    def expire_tag_version
      # $tag_version is bumped when the type of a tag is changed in Tags, if
      # a new tag is created, or if a tag's post_count becomes nonzero.
      Rails.cache.write("$tag_version", Time.now.to_i)
    end

    module_function :expire, :expire_tag_version
  end
end
