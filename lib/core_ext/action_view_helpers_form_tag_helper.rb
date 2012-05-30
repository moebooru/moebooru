# Disable compatibility workaround required on rare case in IE5+.
# Basically, this override removes the utf8=✓ which appears when generating
# form tag.
# Update accordingly.
# Reference: http://stackoverflow.com/a/3348524/260761
#
# version: 3.0.12
# source: actionpack-3.0.12/lib/action_view/helpers/form_tag_helper.rb
module ActionView
  module Helpers
    module FormTagHelper
      # Use this instead once upgraded to Rails >= 3.2
      #def utf8_enforcer_tag
      #  ""
      #end

      private
        def extra_tags_for_form(html_options)
          method = html_options.delete("method").to_s

          method_tag = case method
            when /^get$/i # must be case-insensitive, but can't use downcase as might be nil
              html_options["method"] = "get"
              ''
            when /^post$/i, "", nil
              html_options["method"] = "post"
              token_tag
            else
              html_options["method"] = "post"
              tag(:input, :type => "hidden", :name => "_method", :value => method) + token_tag
          end

          tags = method_tag
          content_tag(:div, tags || '', :style => 'margin:0;padding:0;display:inline')
        end

    end
  end
end
