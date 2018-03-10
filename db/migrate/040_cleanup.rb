class Cleanup < ActiveRecord::Migration[5.1]
  def self.up
    remove_column :forum_posts, :reply_count
    remove_column :users, :user_blacklist
    remove_column :users, :post_threshold
    drop_table :invites
    drop_table :news_updates
  end

  def self.down
    add_column :forum_posts, :reply_count, :integer, :null => false, :default => 0
    add_column :users, :user_blacklist, :text, :null => false, :default => ""
    add_column :users, :post_threshold, :integer, :null => false, :default => -100
    create_table :invites do |_t|
    end
    create_table :news_updates do |_t|
    end
  end
end
