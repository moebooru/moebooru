class DisallowAnonymousForumPosts < ActiveRecord::Migration[5.1]
  def up
    change_column :forum_posts, :creator_id, :integer, :null => false
  end

  def down
    change_column :forum_posts, :creator_id, :integer
  end
end
