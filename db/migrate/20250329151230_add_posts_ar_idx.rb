class AddPostsArIdx < ActiveRecord::Migration[7.2]
  def change
    add_index :posts, '(ROUND(width::numeric / GREATEST(1, height), 3))', name: 'post_ar'
  end
end
