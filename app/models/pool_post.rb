class PoolPost < ActiveRecord::Base
  set_table_name "pools_posts"
  belongs_to :post
  belongs_to :pool
  versioned_parent :pool
  versioning_display :class => :pool
  versioned :active, :default => 'f', :allow_reverting_to_default => true
  versioned :sequence
  before_save :update_pool

  def can_change_is_public?(user)
    return user.has_permission?(pool) # only the owner can change is_public
  end

  def can_change?(user, attribute)
    return false if not user.is_member_or_higher? 
    return pool.is_public? || user.has_permission?(pool)
  end

  def pretty_sequence
    if sequence =~ /^[0-9]+.*/
      return "##{sequence}"
    else
      return "\"#{sequence}\""
    end
  end

  def update_pool
    # Implicit posts never affect the post count, because we always show either the
    # parent or the child posts in the index, but not both.
    return if master_id

    if active_changed? then
      if active then
        pool.increment!(:post_count)
      else
        pool.decrement!(:post_count)
      end

      pool.save!
    end
  end

  # A master pool_post is a post which was added explicitly to the pool whose post has
  # a parent.  A slave pool_post is a post which was added implicitly to the pool, because
  # it has a child which was added to the pool.  (Master/slave terminology is used because
  # calling these parent and child becomes confusing with its close relationship to
  # post parents.)
  #
  # The active flag is always false for an implicit slave post.  Setting the active flag
  # to true on a slave post means you're adding it explicitly, which will cause it to no
  # longer be a slave post.  This behavior cooperates well with history: simply setting
  # and unsetting active are converse operations, regardless of whether a post is a slave
  # or not.  For example, if you have a parent and a child that are both explicitly in the
  # pool, and you remove the parent (causing it to be added as a slave), this will register
  # as a removal in history; undoing that history action will cause the active flag to be
  # set to true again, which will undo as expected.
  belongs_to :master, :class_name => "PoolPost", :foreign_key => "master_id"
  belongs_to :slave, :class_name => "PoolPost", :foreign_key => "slave_id"

protected
  # If our master post is no longer valid, by being deactivated or the post having
  # its parent changed, unlink us from it.
  def detach_stale_master
    # If we already have no master, we have nothing to do.
    return if not self.master

    # If our master has been deactivated, or we've been explicitly activated, or if our
    # master is no longer our child, it's no longer a valid parent.
    return if self.master.active && !self.active && self.master.post.parent_id == self.post_id

    self.master.slave_id = nil
    self.master.save!

    self.master_id = nil
    self.master = nil
    self.save!
   end

  def find_master_and_propagate
    # If we have a master post, verify that it's still valid; if not, detach us from it.
    detach_stale_master

    need_save = false

    # If we have a master, propagate changes from it to us.
    if self.master
      self.sequence = master.sequence
      need_save = true if self.sequence_changed?
    end

    self.save! if need_save
  end

public
  # The specified post has had its parent changed.
  def self.post_parent_changed(post)
    PoolPost.find(:all, :conditions => ["post_id = ?", post.id]).each { |pp|
      pp.need_slave_update = true
      pp.copy_changes_to_slave
    }
  end

  # Since copy_changes_to_slave may call self.save, it needs to be run from
  # post_save and not after_save.  We need to know whether attributes have changed
  # (so we don't run this unnecessarily), so that check needs to be done in after_save,
  # while dirty flags are still set.
  after_save :check_if_need_slave_update
  post_save :copy_changes_to_slave

  attr_accessor :need_slave_update
  def check_if_need_slave_update
    self.need_slave_update = true if sequence_changed? || active_changed?
    return true
  end

  # After a PoolPost or its post changes, update master PoolPosts.
  def copy_changes_to_slave
    return true if !self.need_slave_update
    self.need_slave_update = false

    # If our sequence changed, we need to copy that to our slave (if any), and if our
    # active flag was turned off we need to detach from our slave.
    post_to_update = self.slave

    if !post_to_update && self.active && self.post.parent_id
      # We have no slave, but we have a parent post and we're active, so we might need to
      # assign it.   Make sure that a PoolPost exists for the parent.
      post_to_update = PoolPost.find(:first, :conditions => {:pool_id => self.pool_id, :post_id => post.parent_id})
      if not post_to_update
        post_to_update = PoolPost.create(:pool_id => self.pool_id, :post_id => post.parent_id, :active => false)
      end
    end

    post_to_update.find_master_and_propagate if post_to_update

    self.find_master_and_propagate

    return true
  end
end

