class AddNameToFavoriteTags < ActiveRecord::Migration
  def self.up
    add_foreign_key :favorite_tags, :user_id, :users, :id, :on_delete => :cascade
    add_column :favorite_tags, :name, :string, :null => false, :default => "General"
    add_index :favorite_tags, :name
  end

  def self.down
    remove_column :favorite_tags, :name
    remove_foreign_key "favorite_tags_user_id_fkey"
  end
end
