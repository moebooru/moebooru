class AddUniqueIndexToPostsTag < ActiveRecord::Migration[5.1]
  def self.up
    add_index :posts_tags, [:post_id, :tag_id], :unique => true
  end

  def self.down
    remove_index :posts_tags, :column => [:post_id, :tag_id]
  end
end
