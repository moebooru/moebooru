class RemoveNeighborConstraints < ActiveRecord::Migration[5.1]
  def self.up
    remove_foreign_key :posts, :posts_next_post_id_fkey
    remove_foreign_key :posts, :posts_prev_post_id_fkey
  end

  def self.down
    add_foreign_key :posts, :next_post_id, :posts, :id, :on_delete => :set_null
    add_foreign_key :posts, :prev_post_id, :posts, :id, :on_delete => :set_null
  end
end
