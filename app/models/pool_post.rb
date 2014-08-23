class PoolPost < ActiveRecord::Base
  self.table_name = "pools_posts"
  belongs_to :post
  belongs_to :pool, :touch => true
  belongs_to :next_post, :class_name => "Post", :foreign_key => "next_post_id"
  belongs_to :prev_post, :class_name => "Post", :foreign_key => "prev_post_id"
  versioned_parent :pool
  versioning_group_by :class => :pool
  versioned :active, :default => "f", :allow_reverting_to_default => true
  versioned :sequence
  after_save :expire_cache

  def can_change_is_public?(user)
    user.has_permission?(pool) # only the owner can change is_public
  end

  def can_change?(user, attribute)
    return false if !user.is_member_or_higher?
    pool.is_public? || user.has_permission?(pool)
  end

  # This matches Pool.post_pretty_sequence in pool.js.
  def pretty_sequence
    if sequence =~ /^[0-9]+.*/
      return "##{sequence}"
    else
      return "\"#{sequence}\""
    end
  end

  # Changing pool orderings affects pool sorting in the index.
  def expire_cache
    Moebooru::CacheHelper.expire
  end

  module ApiMethods
    def api_attributes
      {
        :id => id,
        :pool_id => pool_id,
        :post_id => post_id,
        :active => active,
        :sequence => sequence,
        :next_post_id => next_post_id,
        :prev_post_id => prev_post_id,
      }
    end

    def as_json(*params)
      api_attributes.as_json(*params)
    end
  end

  include ApiMethods
end
