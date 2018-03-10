class FixHistoriesColumnName < ActiveRecord::Migration[5.1]
  def change
    rename_column :history_changes, :field, :column_name
  end
end
