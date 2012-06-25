# Disable compatibility workaround required on rare case in IE5+.
# Basically, this override removes the utf8=✓ which appears when generating
# form tag.
# Update accordingly.
# Reference: http://stackoverflow.com/a/3348524/260761
#
# version: 3.2.6
# source: actionpack-3.2.6/lib/action_view/helpers/form_tag_helper.rb
require 'action_view/helpers/form_tag_helper'

module ActionView
  module Helpers
    module FormTagHelper
      def utf8_enforcer_tag
        ""
      end
    end
  end
end
