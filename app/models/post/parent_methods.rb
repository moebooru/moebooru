module Post::ParentMethods
  extend ActiveSupport::Concern

  included do
    after_save :update_parent
    validate :validate_parent
    set_callback :delete, :after, :give_favorites_to_parent
    versioned :parent_id, :default => nil
    has_many :children, lambda { where("status <> ?", "deleted").order("id") },
             :class_name => "Post", :foreign_key => :parent_id
  end

  module ClassMethods
    def update_has_children(post_id)
      has_children = Post.exists?(["parent_id = ? AND status <> 'deleted'", post_id])
      execute_sql("UPDATE posts SET has_children = ? WHERE id = ?", !!has_children, post_id)
    end

    def recalculate_has_children
      transaction do
        where(:has_children => true).update_all(:has_children => false)
        where(:id => available.where.not(:parent_id => nil).select(:parent_id)).update_all(:has_children => true)
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

  def validate_parent
    errors.add("parent_id") unless parent_id.nil? || Post.exists?(parent_id)
  end

  def update_parent
    return if !saved_change_to_parent_id? && !saved_change_to_status?
    self.class.set_parent(id, parent_id, parent_id_before_last_save)
  end

  def give_favorites_to_parent
    return if parent_id.nil?
    parent = Post.find(parent_id)

    transaction do
      post_votes.includes(:user).each do |vote|
        parent.vote!(vote.score, vote.user)
        self.vote!(0, vote.user)
      end
    end
  end

  def get_parent
    self.class.find_by(:id => parent_id)
  end
end
