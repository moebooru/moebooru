class Ban < ActiveRecord::Base
  before_create :save_level
  after_create :save_to_record
  after_create :update_level
  after_destroy :restore_level

  def restore_level
    User.find(user_id).update_attribute(:level, old_level)
  end

  def save_level
    self.old_level = User.find(user_id).level
  end

  def update_level
    user = User.find(user_id)
    user.level = CONFIG["user_levels"]["Blocked"]
    user.save
  end

  def save_to_record
    UserRecord.create(:user_id => self.user_id, :reported_by => self.banned_by, :is_positive => false, :body => "Blocked: #{self.reason}")
  end

  def duration=(dur)
    self.expires_at = (dur.to_f * 60 * 60 * 24).seconds.from_now
    @duration = dur
  end

  def duration
    @duration
  end
end
