class MigrateUsersToContributor < ActiveRecord::Migration
  def self.up
    User.find(:all, :conditions => "level = 30").each do |user|
      post_count = Post.count(:conditions => ["user_id = ? AND status <> 'deleted'", user.id])
      
      if post_count > 50
        user.update_attribute(:level, 33)
      end
    end
    
    User.update_all("invite_count = 0", "level < 35")
  end

  def self.down
    User.update_all("level = 30", "level = 33")
  end
end
