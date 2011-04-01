module PostVoteMethods
  module ClassMethods
    def recalculate_score(id=nil)
      conds = []
      cond_params = []

      sql = "UPDATE posts AS p SET score = " +
        "(SELECT COALESCE(SUM(GREATEST(?, LEAST(?, score))), 0) FROM post_votes v WHERE v.post_id = p.id) "
      cond_params << CONFIG["vote_sum_min"]
      cond_params << CONFIG["vote_sum_max"]

      if id
        conds << "WHERE p.id = ?"
        cond_params << id
      end

      sql = [sql, conds].join(" ")
      execute_sql sql, *cond_params
    end
  end

  def self.included(m)
    m.extend(ClassMethods)
  end

  def recalculate_score!()
    save!
    Post.recalculate_score(self.id)
    connection.clear_query_cache
    reload
  end

  def vote!(score, user, options={})
    score = CONFIG["vote_record_min"] if score < CONFIG["vote_record_min"]
    score = CONFIG["vote_record_max"] if score > CONFIG["vote_record_max"]

    if user.is_anonymous?
      return false
    end
    vote = PostVotes.find_by_ids(user.id, self.id)

    if not vote
      vote = PostVotes.find_or_create_by_id(user.id, self.id)
    end

    vote.update_attributes(:score => score, :updated_at => Time.now)

    recalculate_score!

    return true
  end
end
