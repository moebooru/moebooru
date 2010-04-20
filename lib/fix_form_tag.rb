require "action_view/helpers/tag_helper.rb"

# submit_tag "Search" generates a submit tag that adds "commit=Search" to the URL,
# which is ugly and unnecessary.  Override TagHelper#tag and remove this globally.
module ActionView
  module Helpers
    module TagHelper
      alias_method :orig_tag, :tag
      def tag(name, options = nil, open = false, escape = true)

        if name == :input && options["type"] == "submit" && options["name"] == "commit" && options["value"] == "Search"
          options.delete("name")
        end

        orig_tag name, options, open, escape
      end
    end
  end
end

