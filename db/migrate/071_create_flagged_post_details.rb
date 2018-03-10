class Post < ActiveRecord::Base
end

class FlaggedPostDetail < ActiveRecord::Base
end

class CreateFlaggedPostDetails < ActiveRecord::Migration[5.1]
  def self.up
    remove_column :posts, :approved_by

    create_table :flagged_post_details do |t|
      t.column :created_at, :datetime, :null => false
      t.column :post_id, :integer, :null => false
      t.column :reason, :text, :null => false
      t.column :user_id, :integer, :null => false
      t.column :is_resolved, :boolean, :null => false
    end

    add_index :flagged_post_details, :post_id
    add_foreign_key :flagged_post_details, :post_id, :posts, :id
    add_foreign_key :flagged_post_details, :user_id, :users, :id

    Post.find(:all, :conditions => "deletion_reason <> ''", :select => "deletion_reason, id, status").each do |post|
      FlaggedPostDetail.create(:post_id => post.id, :reason => post.deletion_reason, :user_id => 1, :is_resolved => (post.status == "deleted"))
    end

    remove_column :posts, :deletion_reason
  end

  def self.down
    add_column :posts, :approved_by, :integer
    add_foreign_key :posts, :approved_by, :users, :id
    drop_table :flagged_post_details
    add_column :posts, :deletion_reason, :text, :null => false, :default => ""
  end
end
