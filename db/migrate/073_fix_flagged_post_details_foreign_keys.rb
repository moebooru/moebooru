class FixFlaggedPostDetailsForeignKeys < ActiveRecord::Migration[5.1]
  def self.up
    remove_foreign_key :flagged_post_details, :flagged_post_details_post_id_fkey
    remove_foreign_key :flagged_post_details, :flagged_post_details_user_id_fkey
    add_foreign_key :flagged_post_details, :post_id, :posts, :id, :on_delete => :cascade
    add_foreign_key :flagged_post_details, :user_id, :users, :id, :on_delete => :cascade
  end

  def self.down
    remove_foreign_key :flagged_post_details, :flagged_post_details_post_id_fkey
    remove_foreign_key :flagged_post_details, :flagged_post_details_user_id_fkey
    add_foreign_key :flagged_post_details, :post_id, :posts, :id
    add_foreign_key :flagged_post_details, :user_id, :users, :id
  end
end
