if defined?(::Encoding)
  require "rack/utils"

  module Rack::Utils
    def unescape(s, encoding = Encoding::UTF_8)
      decoded_string = URI.decode_www_form_component(s, encoding)
      decoded_string.valid_encoding? ? decoded_string : nil
    rescue ArgumentError
      nil
    end
    module_function :unescape
  end
end
