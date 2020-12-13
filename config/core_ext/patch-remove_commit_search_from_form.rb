# - removes commit=Search from query url
module ActionView
  module Helpers
    module TagHelperWithRemoveCommitSearch
      # submit_tag "Search" generates a submit tag that adds "commit=Search" to the URL,
      # which is ugly and unnecessary.  Override TagHelper#tag and remove this globally.
      def tag(name, options = nil, open = false, escape = true)
        if name == :input && options["type"] == "submit" && options["name"] == "commit" && options["value"] == "Search"
          options.delete "name"
        end

        super
      end
    end

    module TagHelper
      prepend TagHelperWithRemoveCommitSearch
    end
  end
end
