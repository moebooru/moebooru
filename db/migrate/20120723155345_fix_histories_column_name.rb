class FixHistoriesColumnName < ActiveRecord::Migration
  def change
    rename_column :history_changes, :field, :column_name
  end
end
