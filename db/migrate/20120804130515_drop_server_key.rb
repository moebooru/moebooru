class DropServerKey < ActiveRecord::Migration
  def up
    drop_table :server_keys
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
