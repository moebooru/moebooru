class PoolPost < ActiveRecord::Base
  set_table_name "pools_posts"
  belongs_to :post
  belongs_to :pool
  versioned_parent :pool
  versioning_group_by :class => :pool
  versioned :active, :default => 'f', :allow_reverting_to_default => true
  versioned :sequence
  before_save :update_pool
  after_save :expire_cache

  def can_change_is_public?(user)
    return user.has_permission?(pool) # only the owner can change is_public
  end

  def can_change?(user, attribute)
    return false if not user.is_member_or_higher? 
    return pool.is_public? || user.has_permission?(pool)
  end

  # This matches Pool.post_pretty_sequence in pool.js.
  def pretty_sequence
    if sequence =~ /^[0-9]+.*/
      return "##{sequence}"
    else
      return "\"#{sequence}\""
    end
  end

  def update_pool
    # If active has changed, update our pool's count.  (Don't use active_changed?; that'll
    # be true if active was modified and then set back to its original value.)  Tricky:
    # if we're creating a new record, we need to treat active as changed so we increment
    # the count.  In this case, self.id will be nil, since we havn't saved ourself yet.
    if self.active != self.active_was or self.id == nil then
      if active then
        pool.increment!(:post_count)
      else
        pool.decrement!(:post_count)
      end

      pool.save!
    end
  end

  # Changing pool orderings affects pool sorting in the index.
  def expire_cache
    Cache.expire
  end
end

