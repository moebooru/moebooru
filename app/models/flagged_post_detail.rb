class FlaggedPostDetail < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  
  # If this is set, the user who owns this record won't be included in the API.
  attr_accessor :hide_user

  def author
    if self.user_id.nil?
      return "system"
    else
      return User.find_name(self.user_id)
    end
  end

  def self.new_deleted_posts(user)
    return 0 if user.is_anonymous?

    return Cache.get("deleted_posts:#{user.id}:#{user.last_deleted_post_seen_at.to_i}", 1.minute) do
      select_value_sql(
        "SELECT COUNT(*) FROM flagged_post_details fpd JOIN posts p ON (p.id = fpd.post_id) " +
        "WHERE p.status = 'deleted' AND p.user_id = ? AND fpd.user_id <> ? AND fpd.created_at > ?",
          user.id, user.id, user.last_deleted_post_seen_at).to_i
    end
  end

  def flagged_by
    return User.find_name(user_id)
  end

  def api_attributes
    ret = {
      :post_id => post_id,
      :reason => reason,
      :created_at => created_at,
    }

    if not hide_user then
      ret[:user_id] = user_id
      ret[:flagged_by] = flagged_by
    end

    return ret
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.reverse_merge(:root => "flagged_post_detail"))
  end
end
