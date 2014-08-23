# This overwrites Rails' json_escape method.
# The reason this is done is because the current implementation
# is pretty much useless since it returns *invalid* json and therefore
# doesn't have any practical use.
#
# reference: http://jfire.io/blog/2012/04/30/how-to-securely-bootstrap-json-in-a-rails-view/
#
require "active_support/core_ext/string/output_safety"
class ERB
  module Util
    def json_escape(s)
      result = s.to_s.gsub("/", '\/')
      s.html_safe? ? result.html_safe : result
    end
  end
end
