class ForumPost < ActiveRecord::Base
  belongs_to :creator, :class_name => "User", :foreign_key => :creator_id
  after_create :initialize_last_updated_by
  before_validation :validate_title
  validates_length_of :body, :minimum => 1, :message => "You need to enter a body"

  module LockMethods
    module ClassMethods
      def lock!(id)
        # Run raw SQL to skip the lock check
        execute_sql("UPDATE forum_posts SET is_locked = TRUE WHERE id = ?", id)
      end

      def unlock!(id)
        # Run raw SQL to skip the lock check
        execute_sql("UPDATE forum_posts SET is_locked = FALSE WHERE id = ?", id)
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
      m.before_validation :validate_lock
    end

    def validate_lock
      if root.is_locked?
        errors.add_to_base("Thread is locked")
        return false
      end

      return true
    end
  end

  module StickyMethods
    module ClassMethods
      def stick!(id)
        # Run raw SQL to skip the lock check
        execute_sql("UPDATE forum_posts SET is_sticky = TRUE WHERE id = ?", id)
      end

      def unstick!(id)
        # Run raw SQL to skip the lock check
        execute_sql("UPDATE forum_posts SET is_sticky = FALSE WHERE id = ?", id)
      end
    end

    def self.included(m)
      m.extend(ClassMethods)
    end
  end

  module ParentMethods
    def self.included(m)
      m.after_create :update_parent_on_create
      m.before_destroy :update_parent_on_destroy
      m.has_many :children, :class_name => "ForumPost", :foreign_key => :parent_id, :order => "id"
      m.belongs_to :parent, :class_name => "ForumPost", :foreign_key => :parent_id
    end

    def update_parent_on_destroy
      unless is_parent?
        p = parent
        p.update_attributes(:response_count => p.response_count - 1)
      end
    end

    def update_parent_on_create
      unless is_parent?
        p = parent
        p.update_attributes(:updated_at => updated_at, :response_count => p.response_count + 1, :last_updated_by => creator_id)
      end
    end

    def is_parent?
      return parent_id.nil?
    end

    def root
      if is_parent?
        return self
      else
        return ForumPost.find(parent_id)
      end
    end

    def root_id
      if is_parent?
        return id
      else
        return parent_id
      end
    end
  end

  module ApiMethods
    def api_attributes
      return {
        :body => body,
        :creator => author,
        :creator_id => creator_id,
        :id => id,
        :parent_id => parent_id,
        :title => title
      }
    end

    def as_json(*params)
      api_attributes.as_json(*params)
    end

    def to_xml(options = {})
      api_attributes.to_xml(options.reverse_merge(:root => "forum_post"))
    end
  end

  include LockMethods
  include StickyMethods
  include ParentMethods
  include ApiMethods

  def self.updated?(user)
    conds = []
    conds += ["creator_id <> %d" % [user.id]] unless user.is_anonymous?

    newest_topic = ForumPost.find(:first, :order => "id desc", :limit => 1, :select => "created_at", :conditions => conds)
    return false if newest_topic == nil
    return newest_topic.created_at > user.last_forum_topic_read_at
  end

  def validate_title
    if is_parent?
      if title.blank?
        errors.add :title, "missing"
        return false
      end

      if title !~ /\S/
        errors.add :title, "missing"
        return false
      end
    end

    return true
  end

  def initialize_last_updated_by
    if is_parent?
      update_attribute(:last_updated_by, creator_id)
    end
  end

  def last_updater
    User.find_name(last_updated_by)
  end

  def author
    User.find_name(creator_id)
  end
end
