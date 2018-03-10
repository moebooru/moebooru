class AddVisibleOnProfileToTagSubscriptions < ActiveRecord::Migration[5.1]
  def self.up
    remove_index :favorite_tags, :name
    remove_index :favorite_tags, :user_id
    remove_foreign_key :favorite_tags, "favorite_tags_user_id_fkey"
    rename_table :favorite_tags, :tag_subscriptions
    add_index :tag_subscriptions, :name
    add_index :tag_subscriptions, :user_id
    add_foreign_key :tag_subscriptions, :user_id, :users, :id, :on_delete => :cascade
    add_column :tag_subscriptions, :is_visible_on_profile, :boolean, :null => false, :default => true
  end

  def self.down
    remove_column :tag_subscriptions, :is_visible_on_profile
    remove_foreign_key :tag_subsriptions, "tag_subscriptions_user_id_fkey"
    remove_index :tag_subscriptions, :user_id
    remove_index :tag_subscriptions, :name
    rename_table :tag_subscriptions, :favorite_tags
    add_foreign_key :favorite_tags, :user_id, :users, :id, :on_delete => :cascade
    add_index :favorite_tags, :user_id
    add_index :favorite_tags, :name
  end
end
