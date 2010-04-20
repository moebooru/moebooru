class PostVotes < ActiveRecord::Base
  belongs_to :post, :class_name => "Post", :foreign_key => :post_id
  belongs_to :user, :class_name => "User", :foreign_key => :user_id

  def self.find_by_ids(user_id, post_id)
    self.find(:first, :conditions => ["user_id = ? AND post_id = ?", user_id, post_id])
  end

  def self.find_or_create_by_id(user_id, post_id)
    entry = self.find_by_ids(user_id, post_id)

    if entry
      return entry
    else
      return create(:user_id => user_id, :post_id => post_id)
    end
  end
end
