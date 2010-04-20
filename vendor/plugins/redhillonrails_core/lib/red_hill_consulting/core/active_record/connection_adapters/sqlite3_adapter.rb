module RedHillConsulting::Core::ActiveRecord::ConnectionAdapters
  module Sqlite3Adapter
    def add_foreign_key(table_name, column_names, references_table_name, references_column_names, options = {})
    end

    def remove_foreign_key(table_name, foreign_key_name)
    end
  end
end
