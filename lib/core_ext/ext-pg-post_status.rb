if RUBY_PLATFORM != "java"
  require "active_record/connection_adapters/abstract_adapter"

  module ActiveRecord
    module ConnectionAdapters
      class PostgreSQLAdapter < AbstractAdapter
        module OID
          alias_type "post_status", "text"
        end
      end
    end
  end
end
