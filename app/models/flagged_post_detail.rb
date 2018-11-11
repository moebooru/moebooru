class FlaggedPostDetail < ApplicationRecord
  belongs_to :post
  belongs_to :user

  # If this is set, the user who owns this record won't be included in the API.
  attr_accessor :hide_user

  def author
    if user_id.nil?
      return "system"
    else
      return User.find_name(user_id)
    end
  end

  def self.new_deleted_posts(user)
    return 0 if user.is_anonymous?

    Rails.cache.fetch("deleted_posts:#{user.id}:#{user.last_deleted_post_seen_at.to_i}", :expires_in => 1.minute) do
      select_value_sql(
        "SELECT COUNT(*) FROM flagged_post_details fpd JOIN posts p ON (p.id = fpd.post_id) " \
        "WHERE p.status = 'deleted' AND p.user_id = ? AND fpd.user_id <> ? AND fpd.created_at > ?",
        user.id, user.id, user.last_deleted_post_seen_at).to_i
    end
  end

  # XXX: author and flagged_by are redundant
  def flagged_by
    if user_id.nil?
      return "system"
    else
      return User.find_name(user_id)
    end
  end

  def api_attributes
    ret = {
      :post_id => post_id,
      :reason => reason,
      :created_at => created_at
    }

    unless hide_user
      ret[:user_id] = user_id
      ret[:flagged_by] = flagged_by
    end

    ret
  end

  def as_json(*args)
    api_attributes.as_json(*args)
  end

  def to_xml(options = {})
    api_attributes.to_xml(options.reverse_merge(:root => "flagged_post_detail"))
  end
end
