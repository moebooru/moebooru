# frozen_string_literal: true

module Moebooru
  # Allows skipping returning cookie for given request
  module SkipCookie
    # Idea from rails csrf protection
    # https://github.com/rails/rails/blob/49e13b226c1265b96119e115fd9380d50ad49fa9/actionpack/lib/action_controller/metal/request_forgery_protection.rb#L159
    def self.apply(request)
      request.session_options[:skip] = true
      request.cookie_jar = NullCookieJar.build(request, {})
    end

    # Blank cookie jar which does nothing
    class NullCookieJar < ActionDispatch::Cookies::CookieJar
      def write(*)
        # nothing
      end
    end
  end
end
