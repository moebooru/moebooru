class CommentObserver < ActiveRecord::Observer
  def after_save(_comment)
  end
end
