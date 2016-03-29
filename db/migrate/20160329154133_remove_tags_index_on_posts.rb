class RemoveTagsIndexOnPosts < ActiveRecord::Migration
  def up
    remove_column :posts, :tags_index
  end
end
