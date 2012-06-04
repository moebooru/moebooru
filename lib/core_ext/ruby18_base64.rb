# Adds urlsafe_encode64 and urlsafe_decode64 for Ruby 1.8.
if RUBY_VERSION < '1.9'
  module Base64
    module_function

    def urlsafe_encode64(str)
      [str].pack('m').tr("\n", '').tr('+/', '-_')
    end

    def urlsafe_decode64(str)
      str.tr('-_', '+/').unpack('m')
    end
  end
end
