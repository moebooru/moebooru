module PostParentMethods
  module ClassMethods
    def update_has_children(post_id)
      has_children = Post.exists?(["parent_id = ? AND status <> 'deleted'", post_id])
      execute_sql("UPDATE posts SET has_children = ? WHERE id = ?", has_children, post_id)
    end

    def recalculate_has_children
      transaction do
        execute_sql("UPDATE posts SET has_children = false WHERE has_children = true")
        execute_sql("UPDATE posts SET has_children = true WHERE id IN (SELECT parent_id FROM posts WHERE parent_id IS NOT NULL AND status <> 'deleted')")
      end
    end

    def set_parent(post_id, parent_id, old_parent_id = nil)
      if old_parent_id.nil?
        old_parent_id = select_value_sql("SELECT parent_id FROM posts WHERE id = ?", post_id)
      end

      if parent_id.to_i == post_id.to_i || parent_id.to_i == 0
        parent_id = nil
      end

      execute_sql("UPDATE posts SET parent_id = ? WHERE id = ?", parent_id, post_id)

      update_has_children(old_parent_id)
      update_has_children(parent_id)
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
    m.after_save :update_parent
    m.validate :validate_parent
    m.after_delete :give_favorites_to_parent
    m.versioned :parent_id, :default => nil
    m.has_many :children, :class_name => "Post", :order => "id",
      :foreign_key => :parent_id, :conditions => "status <> 'deleted'"
  end

  def validate_parent
    errors.add("parent_id") unless parent_id.nil? or Post.exists?(parent_id)
  end

  def update_parent
    return if !parent_id_changed? && !status_changed?
    self.class.set_parent(id, parent_id, parent_id_was)
  end

  def give_favorites_to_parent
    return if parent_id.nil?
    parent = Post.find(parent_id)

    transaction do
      for vote in PostVotes.find(:all, :conditions => ["post_id = ?", self.id], :include => :user)
        parent.vote!(vote.score, vote.user)
        self.vote!(0, vote.user)
      end
    end
  end

  def get_parent
    return Post.find(:first, :conditions => ["id = ?", self.parent_id])
  end
end
