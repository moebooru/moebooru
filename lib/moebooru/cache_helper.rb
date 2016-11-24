module Moebooru
  module CacheHelper
    def increment_version(type = "post")
      Rails.cache.increment("#{type}_version")
    end

    def get_version(type = "post")
      Rails.cache.fetch("#{type}_version", :raw => true) do
        0
      end.to_i
    end

    module_function :increment_version, :get_version
  end
end
