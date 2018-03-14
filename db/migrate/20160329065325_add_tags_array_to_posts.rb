class AddTagsArrayToPosts < ActiveRecord::Migration[5.1]
  def change
    add_column :posts, :tags_array, :string, :array => true
  end
end
