require "activerecord.rb"

class AddPostVotes < ActiveRecord::Migration[5.1]
  def self.up
    create_table :post_votes do |t|
      t.column :user_id, :integer, :null => false
      t.foreign_key :user_id, :users, :id, :on_delete => :cascade
      t.column :post_id, :integer, :null => false
      t.foreign_key :post_id, :posts, :id, :on_delete => :cascade
      t.column :score, :integer, :null => false, :default => 0
      t.column :updated_at, :timestamp, :null => false, :default => "now()"
    end

    # This should probably be the primary key, but ActiveRecord assumes the primary
    # key is a single column.
    execute "ALTER TABLE post_votes ADD UNIQUE (user_id, post_id)"

    add_index :post_votes, :user_id
    add_index :post_votes, :post_id

    add_column :posts, :last_vote, :integer, :null => false, :default => 0
    add_column :posts, :anonymous_votes, :integer, :null => false, :default => 0

    # Set anonymous_votes = score - num favorited
    execute "UPDATE posts SET anonymous_votes = posts.score - (SELECT COUNT(*) FROM favorites f WHERE f.post_id = posts.id)"
  end
  def self.down
    drop_table :post_votes
    remove_column :posts, :last_vote
    remove_column :posts, :anonymous_votes
  end
end
