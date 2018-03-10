class FavoriteTags < ActiveRecord::Migration[5.1]
  def self.up
    create_table :favorite_tags do |t|
      t.column :user_id, :integer, :null => false
      t.column :tag_query, :text, :null => false
      t.column :cached_post_ids, :text, :null => false, :default => ""
    end

    add_index :favorite_tags, :user_id
  end

  def self.down
    drop_table :favorite_tags
  end
end
