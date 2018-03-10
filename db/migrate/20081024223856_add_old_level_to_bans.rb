class AddOldLevelToBans < ActiveRecord::Migration[5.1]
  def self.up
    add_column :bans, :old_level, :integer
  end

  def self.down
    remove_column :bans, :old_level
  end
end
