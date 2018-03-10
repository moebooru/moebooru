class AddBlacklistedTagsToUsers < ActiveRecord::Migration[5.1]
  def self.up
    add_column :users, :blacklisted_tags, :text, :null => false, :default => ""
  end

  def self.down
    remove_column :users, :blacklisted_tags
  end
end
