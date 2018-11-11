class IpBans < ApplicationRecord
  belongs_to :user, :foreign_key => :banned_by

  def duration=(dur)
    if dur.blank?
      self.expires_at = nil
      @duration = nil
    else
      self.expires_at = (dur.to_f * 60 * 60 * 24).seconds.from_now
      @duration = dur
    end
  end

  attr_reader :duration
end
