# This is a workaround for Rails issue:
#   https://github.com/rails/rails/issues/736
#
# We are hitting this as of Rails 3.0.15, and will focus this patch only
# on that version. Upgrades to newer versions of Rails will disable this
# patch, and the test for this may fail if said version of Rails hasn't
# fixed this yet. At that time, this patch may need re-investigation since
# it take advantage of internals of this class.
if Rails.version == "3.0.15"
  module Mime
    class Type
      def self.lookup(string)
        LOOKUP[string.split(';').first]
      end
    end
  end
end
