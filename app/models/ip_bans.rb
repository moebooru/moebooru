class IpBans < ActiveRecord::Base
  belongs_to :user, :foreign_key => :banned_by

  def duration=(dur)
    if not dur or dur == "" then
      self.expires_at = nil
      @duration = nil
    else
      self.expires_at = (dur.to_f * 60*60*24).seconds.from_now
      @duration = dur
    end
  end

  def duration
    @duration
  end
end
