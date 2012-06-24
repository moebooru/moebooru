# This is a workaround for Rail issue:
#   https://github.com/rails/rails/issues/860
#
# We are hitting this as of Rails 3.0.15, and will focus this patch only
# on that version. Upgrades to newer versions of Rails will disable this
# patch, and the test for this may fail if said version of Rails hasn't
# fixed this yet. At that time, this patch may need re-investigation since
# it takes advantage of internals of this class.
#
# Allegedly, this *has* been fixed in later versions of Rails.
#
# This patch is mainly taken from the implementation of Mime::Type.parse
# and Mime::Type.parse_data_with_trailing_star from the HEAD of Rails master
# on 2012-02-06:
#   https://github.com/rails/rails/blob/4d5266e2706195888c9f72fdc9ebde22f89a08df/actionpack/lib/action_dispatch/http/mime_type.rb
# With the one small addition that this patch also correctly handles
# image/* types.
#
if Rails.version == "3.0.15"
  module Mime
    class Type

      TRAILING_STAR_REGEXP = /(text|application|image)\/\*/
      
      def self.parse(accept_header)
        if accept_header !~ /,/
          if accept_header =~ TRAILING_STAR_REGEXP
            parse_data_with_trailing_star($1)
          else
            [Mime::Type.lookup(accept_header)]
          end
        else
          # keep track of creation order to keep the subsequent sort stable
          list, index = [], 0
          accept_header.split(/,/).each do |header|
            params, q = header.split(/;\s*q=/)
            if params.present?
              params.strip!

              if params =~ TRAILING_STAR_REGEXP
                parse_data_with_trailing_star($1).each do |m|
                  list << AcceptItem.new(index, m.to_s, q)
                  index += 1
                end
              else
                list << AcceptItem.new(index, params, q)
                index += 1
              end
            end
          end
          list.sort!

          # Take care of the broken text/xml entry by renaming or deleting it
          text_xml = list.index("text/xml")
          app_xml = list.index(Mime::XML.to_s)

          if text_xml && app_xml
            # set the q value to the max of the two
            list[app_xml].q = [list[text_xml].q, list[app_xml].q].max

            # make sure app_xml is ahead of text_xml in the list
            if app_xml > text_xml
              list[app_xml], list[text_xml] = list[text_xml], list[app_xml]
              app_xml, text_xml = text_xml, app_xml
            end

            # delete text_xml from the list
            list.delete_at(text_xml)

          elsif text_xml
            list[text_xml].name = Mime::XML.to_s
          end

          # Look for more specific XML-based types and sort them ahead of app/xml

          if app_xml
            idx = app_xml
            app_xml_type = list[app_xml]

            while(idx < list.length)
              type = list[idx]
              break if type.q < app_xml_type.q
              if type.name =~ /\+xml$/
                list[app_xml], list[idx] = list[idx], list[app_xml]
                app_xml = idx
              end
              idx += 1
            end
          end

          list.map! { |i| Mime::Type.lookup(i.name) }.uniq!
          list
        end
      end

      # input: 'text'
      # returned value:  [Mime::JSON, Mime::XML, Mime::ICS, Mime::HTML, Mime::CSS, Mime::CSV, Mime::JS, Mime::YAML, Mime::TEXT]
      #
      # input: 'application'
      # returned value: [Mime::HTML, Mime::JS, Mime::XML, Mime::YAML, Mime::ATOM, Mime::JSON, Mime::RSS, Mime::URL_ENCODED_FORM]
      def self.parse_data_with_trailing_star(input)
        Mime::SET.select { |m| m =~ input }
      end

    end
  end
end
