# This one handles sanitizing params.
# Taken from https://github.com/rails/rails/pull/3789/files
require 'action_dispatch/http/parameters'

module ActionDispatch
  module Http
    module Parameters
    private
      def encode_params(params)
        return params unless "ruby".encoding_aware?
        if params.is_a?(String)
          return ActionDispatch::Encoder::encode_to_internal(params)
        elsif !params.is_a?(Hash)
          return params
        end

        params.each do |k, v|
          case v
          when Hash
            encode_params(v)
          when Array
            v.map! {|el| encode_params(el) }
          else
            encode_params(v)
          end
        end
      end
    end
  end
end
