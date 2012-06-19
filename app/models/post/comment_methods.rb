module PostCommentMethods
  def self.included(m)
    m.has_many :comments, :order => "id"
  end

  def recent_comments
    Comment.find(:all, :conditions => ["post_id = ?", id], :order => "id desc", :limit => 6).reverse
  end
end
