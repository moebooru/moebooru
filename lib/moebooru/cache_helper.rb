module Moebooru
  module CacheHelper
    def increment_version(type = "post")
      Rails.cache.increment("#{type}_version")
    end

    def get_version(type = "post")
      Rails.cache.read("#{type}_version").to_i
    end

    module_function :increment_version, :get_version
  end
end
