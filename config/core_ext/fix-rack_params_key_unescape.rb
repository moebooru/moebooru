require "rack/utils"

module Rack::Utils
  # Refuse to unescape anything other than UTF-8.
  def unescape(s, _encoding = "")
    # *Might* be garbage string. Scrub.
    URI.decode_www_form_component(s, Encoding::UTF_8).to_valid_utf8
  rescue ArgumentError
    # Garbage string. Scrub.
    s.to_valid_utf8
  end
  module_function :unescape
end
