class DropServerKey < ActiveRecord::Migration[5.1]
  def up
    drop_table :server_keys
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
