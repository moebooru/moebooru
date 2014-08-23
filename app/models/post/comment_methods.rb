module Post::CommentMethods
  def self.included(m)
    m.has_many :comments, lambda { order "id" }
  end

  def recent_comments
    # reverse_order to fetch last 6 comments
    # reversed in the last to return from lowest id
    comments.reverse_order.limit(6).reverse
  end
end
