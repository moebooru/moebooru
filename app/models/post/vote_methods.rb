module PostVoteMethods
  module ClassMethods
    def recalculate_score(id=nil)
      conds = []
      cond_params = []

      sql = "UPDATE posts AS p SET score = " +
        "(SELECT COALESCE(SUM(GREATEST(?, LEAST(?, score))), 0) FROM post_votes v WHERE v.post_id = p.id) " +
        "+ p.anonymous_votes"
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

  def vote!(score, user, ip_addr, options={})
    score = CONFIG["vote_record_min"] if score < CONFIG["vote_record_min"]
    score = CONFIG["vote_record_max"] if score > CONFIG["vote_record_max"]

    if user.is_anonymous?
      score = 0 if score < 0
      score = 1 if score > 1

      if last_voter_ip == ip_addr
        return false
      end

      self.anonymous_votes += score
      self.last_voter_ip = ip_addr
      self.last_vote = score
    else
      vote = PostVotes.find_by_ids(user.id, self.id)

      if ip_addr and last_voter_ip == ip_addr and not vote
        # The user voted anonymously, then logged in and tried to vote again.  A user
        # may be browsing anonymously, decide to make an account, then once he has access
        # to full voting, decide to set his permanent vote.  Just undo the anonymous vote.
        self.anonymous_votes -= self.last_vote
        self.last_vote = 0
      end

      if not vote
        vote = PostVotes.find_or_create_by_id(user.id, self.id)
      end

      vote.update_attributes(:score => score, :updated_at => Time.now)
    end

    recalculate_score!

    return true
  end
end
