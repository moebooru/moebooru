module PostRatingMethods
  attr_accessor :old_rating

  def self.included(m)
    m.versioned :rating
    m.versioned :is_rating_locked, :default => false
    m.versioned :is_note_locked, :default => false
  end

  def rating=(r)
    if r == nil && !new_record?
      return
    end

    if is_rating_locked?
      return
    end

    r = r.to_s.downcase[0, 1]

    if %w(q e s).include?(r)
      new_rating = r
    else
      new_rating = 'q'
    end

    return if rating == new_rating
    self.old_rating = rating
    write_attribute(:rating, new_rating)
    touch_change_seq!
  end

  def pretty_rating
    case rating
    when "q"
      return "Questionable"

    when "e"
      return "Explicit"

    when "s"
      return "Safe"
    end
  end

  def can_change_is_note_locked?(user)
    return user.has_permission?(pool)
  end
  def can_change_rating_locked?(user)
    return user.has_permission?(pool)
  end
  def can_change_rating?(user)
    return user.is_member_or_higher? && (!is_rating_locked? || user.has_permission?(self))
  end
end
