class CommentObserver < ActiveRecord::Observer
  def after_save(comment)
    Rails.cache.delete({ :type => :comment_formatted_body, :id => comment.id })
  end
end
