class AddBlacklistedTagsToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :blacklisted_tags, :text, :null => false, :default => ""
  end

  def self.down
    remove_column :users, :blacklisted_tags
  end
end
