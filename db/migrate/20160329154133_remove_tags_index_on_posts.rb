class RemoveTagsIndexOnPosts < ActiveRecord::Migration[5.1]
  def up
    remove_column :posts, :tags_index
  end
end
