# Fix for a Rails - Ruby 1.9 bug
# Rails Router, now that it's UTF-8 default, blows up when routing requests
# with invalid chars in the URL; it should properly return a 400 error
# Have to monkey-patch the fix in, since it's not scheduled for release until
# Rails 4.0.
# Adapted Andrew White (pixeltrix)'s fix at
# https://github.com/rails/rails/commit/3fc561a1f71edf1c2bae695cafa03909d24a5ca3,
# but edited to work in 3.0.x.
# 3.1.x, 3.2.x compatibility unknown
require 'action_dispatch/routing/route_set'

if RUBY_VERSION >= '1.9'
  module ActionDispatch
    module Routing
      class RouteSet
        class Dispatcher
          def call_with_invalid_char_handling(env)
            params = env[PARAMETERS_KEY]

            # If any of the path parameters has a invalid encoding then
            # raise since it's likely to trigger errors further on.
            params.each do |key, value|
              if value.is_a?(String) and !value.valid_encoding?
                return [400, {'X-Cascade' => 'pass'}, []]
              end
            end
            call_without_invalid_char_handling(env)
          end

          alias_method_chain :call, :invalid_char_handling
        end
      end
    end
  end
end
