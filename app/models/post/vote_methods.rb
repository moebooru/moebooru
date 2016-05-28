module Post::VoteMethods
  module ClassMethods
    def recalculate_score(id = nil)
      conds = []
      cond_params = []

      sql = "UPDATE posts AS p SET score = " \
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

  def recalculate_score!
    save!
    Post.recalculate_score(id)
    reload
  end

  def vote!(score, user, _options = {})
    score = CONFIG["vote_record_min"] if score < CONFIG["vote_record_min"]
    score = CONFIG["vote_record_max"] if score > CONFIG["vote_record_max"]

    if user.is_anonymous?
      return false
    end

    if score > 0
      begin
        transaction do
          vote = post_votes.lock.find_or_initialize_by :user_id => user.id
          vote.update :score => score
        end
      rescue ActiveRecord::RecordNotUnique
        retry
      end
    else
      post_votes.where(:user_id => user.id).delete_all
    end

    recalculate_score!

    true
  end
end
