class AddPoolsDefaultToUser < ActiveRecord::Migration[5.1]
  def self.up
    add_column :users, :pool_browse_mode, :integer, :null => false, :default => 1
  end

  def self.down
    remove_column :users, :pool_browse_mode
  end
end
