class AddPostForeignKeyToPostsTags < ActiveRecord::Migration[5.1]
  def change
    execute <<-SQL
      DELETE FROM posts_tags
        WHERE posts_tags.post_id NOT IN
          (SELECT posts.id FROM posts WHERE posts.id = posts_tags.post_id)
    SQL
    add_foreign_key :posts_tags, :posts, :dependent => :delete
  end
end
