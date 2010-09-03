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

  # This matches Pool.post_pretty_sequence in pool.js.
  def pretty_sequence
    if sequence =~ /^[0-9]+.*/
      return "##{sequence}"
    else
      return "\"#{sequence}\""
    end
  end

  def update_pool
    if active_changed? then
      if active then
        pool.increment!(:post_count)
      else
        pool.decrement!(:post_count)
      end

      pool.save!
    end
  end
end

