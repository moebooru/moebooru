# - removes commit=Search from query url
module ActionView
  module Helpers
    module TagHelper
      # submit_tag "Search" generates a submit tag that adds "commit=Search" to the URL,
      # which is ugly and unnecessary.  Override TagHelper#tag and remove this globally.
      def tag_with_remove_commit_search(name, options = nil, open = false, escape = true)
        if name == :input && options["type"] == "submit" && options["name"] == "commit" && options["value"] == "Search"
          options.delete "name"
        end
        tag_without_remove_commit_search name, options, open, escape
      end
      alias_method_chain :tag, :remove_commit_search
    end
  end
end
