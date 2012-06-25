# Yet another fix for utf8
# https://github.com/rails/rails/pull/3789/files
require 'core_ext/action_dispatch_encoder'
require 'action_dispatch/http/upload'

module ActionDispatch
  module Http
    class UploadedFile
      private
      def encode_filename(filename)
        # Encode the filename in the utf8 encoding, unless it is nil or we're in 1.8
        if "ruby".encoding_aware? && filename
          ActionDispatch::Encoder::encode_to_internal(filename)
        else
          filename
        end
      end
    end
  end
end
