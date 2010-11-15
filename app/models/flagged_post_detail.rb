class FlaggedPostDetail < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  
  def author
    return User.find_name(self.user_id)
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
      :user_id => user_id,
      :flagged_by => flagged_by,
      :created_at => created_at,
    }

    return ret
  end

  def to_json(*args)
    return api_attributes.to_json(*args)
  end

  def to_xml(options = {})
    return api_attributes.to_xml(options.merge(:root => "flagged_post_detail"))
  end
end
