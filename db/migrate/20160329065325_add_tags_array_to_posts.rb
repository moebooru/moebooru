class AddTagsArrayToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :tags_array, :string, :array => true
  end
end
