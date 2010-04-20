# Override default tag helper to output HTMl 4 code
module ActionView
  module Helpers #:nodoc:
    module TagHelper
      # Disable open; validates better...
      def tag(name, options = nil, open = true, escape = true)
        # workaround: PicLens is rendered as HTML, instead of XML, so don't force open tags 
        # based on MIME type instead of template_format
        if headers["Content-Type"] != "application/rss+xml"
          open = true
        end

        "<#{name}#{tag_options(options, escape) if options}" + (open ? ">" : " />")
      end
    end
    
    module AssetTagHelper
      def stylesheet_tag(source, options)
        tag("link", { "rel" => "stylesheet", "type" => Mime::CSS, "media" => "screen", "href" => html_escape(path_to_stylesheet(source)) }.merge(options), false, false)
      end
    end
    
    class InstanceTag
      def tag(name, options = nil, open = true, escape = true)
        "<#{name}#{tag_options(options, escape) if options}" + (open ? ">" : " />")
      end
    end
  end
end
