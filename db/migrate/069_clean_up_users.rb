class CleanUpUsers < ActiveRecord::Migration
  def self.up
    remove_column :users, :ip_addr
    remove_column :users, :tag_blacklist
    remove_column :users, :login_count
  end

  def self.down
    execute "ALTER TABLE users ADD COLUMN ip_addr inet NOT NULL"
    add_column :users, :tag_blacklist, :text, :null => false, :default => ""
    add_column :users, :login_count, :integer, :null => false, :default => 0
  end
end
