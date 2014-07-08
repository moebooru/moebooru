# Reference: https://coderwall.com/p/azi3ka
# FIXME: only applies for rails 4.0.
if RUBY_PLATFORM != "java"
  require "active_record/connection_adapters/abstract_adapter"

  module ActiveRecord
    module ConnectionAdapters
      class PostgreSQLAdapter < AbstractAdapter
        module OID
          alias_type "post_status", "text"
        end
      end

      class Column
        private

        def simplified_type_with_post_status_type(field_type)
          if field_type == "post_status"
            field_type.to_sym
          else
            simplified_type_without_post_status_type field_type
          end
        end
        alias_method_chain :simplified_type, :post_status_type
      end
    end
  end
end
