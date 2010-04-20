class RemoveNeighborFieldsFromPosts < ActiveRecord::Migration
  def self.up
    remove_column :posts, :next_post_id
    remove_column :posts, :prev_post_id
  end

  def self.down
    add_column :posts, :next_post_id, :integer
    add_column :posts, :prev_post_id, :integer
  end
end
