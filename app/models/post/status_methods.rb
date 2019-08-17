module Post::StatusMethods
  def status=(s)
    return if s == status
    write_attribute(:status, s)
    touch_change_seq!
  end

  def reset_index_timestamp
    self.index_timestamp = created_at
  end

  # Bump the post to the front of the index.
  def touch_index_timestamp
    self.index_timestamp = Time.now
  end

  module ClassMethods
    # If user_id is nil, allow activating any user's posts.
    def batch_activate(user_id, post_ids)
      conds = []
      cond_params = []

      conds << "is_held = true"
      conds << "id IN (?)"
      cond_params << post_ids

      if user_id
        conds << "user_id = ?"
        cond_params << user_id
      end

      # Tricky: we want posts to show up in the index in the same order they were posted.
      # If we just bump the posts, the index_timestamps will all be the same, and they'll
      # show up in an undefined order.  We don't want to do this in the ORDER BY when
      # searching, because that's too expensive.  Instead, tweak the timestamps slightly:
      # for each post updated, set the index_timestamps 1ms newer than the previous.
      #
      # Returns the number of posts actually activated.
      count = nil
      transaction do
        # result_id gives us an index for each result row; multiplying this by 1ms
        # gives us an increasing counter.  This should be a lot easier than this.
        sql = <<-EOS
          CREATE TEMP SEQUENCE result_id;

          UPDATE posts
          SET index_timestamp = now() + (interval '1 ms' * idx)
          FROM
           (SELECT nextval('result_id') AS idx, * FROM (
             SELECT id, index_timestamp FROM posts
               WHERE #{conds.join(" AND ")}
             ORDER BY created_at DESC
           ) AS n) AS nn
          WHERE posts.id IN (nn.id);

          DROP SEQUENCE result_id;
        EOS
        execute_sql(sql, *cond_params)

        count = select_value_sql("SELECT COUNT(*) FROM posts WHERE #{conds.join(" AND ")}", *cond_params).to_i

        sql = "UPDATE posts SET is_held = false WHERE #{conds.join(" AND ")}"
        execute_sql(sql, *cond_params)
      end

      Moebooru::CacheHelper.increment_version if count > 0

      count
    end
  end

  def update_status_on_destroy
    # Can't use update here since this method is wrapped inside of a destroy call
    execute_sql("UPDATE posts SET status = ? WHERE id = ?", "deleted", id)
    Post.update_has_children(parent_id) if parent_id
    flag_detail.update(:is_resolved => true) if flag_detail
    false
  end

  def self.included(m)
    m.extend(ClassMethods)
    m.before_create :reset_index_timestamp
    m.versioned :is_shown_in_index, :default => true

    # This is only used on initial creation: if the post is initially set to flagged or
    # pending, this may contain the reason, which will be stored as a flagged_post_detail
    # on save; we can't save it before then since we don't yet have an ID to create the row.
    m.after_save :commit_status_reason
    attr_accessor :status_reason
  end

  def commit_status_reason
    return if status_reason.nil?
    set_flag_detail(status_reason, nil)
  end

  def is_held=(hold)
    # Hack because the data comes in as a string:
    hold = false if hold == "false"

    user = Thread.current["danbooru-user"]

    # Only the original poster can hold or unhold a post.
    return if user && !user.has_permission?(self)

    if hold
      # A post can only be held within one minute of posting (except by a moderator);
      # this is intended to be used on initial posting, before it shows up in the index.
      return if created_at && created_at < 1.minute.ago
    end

    was_held = is_held

    write_attribute(:is_held, hold)

    # When a post is unheld, bump it.
    if was_held && !hold
      touch_index_timestamp
    end
  end

  def undelete!
    self.status = "active"
    self.save!
    Post.update_has_children(parent_id) if parent_id
  end
end
