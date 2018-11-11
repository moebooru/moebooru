class Advertisement < ApplicationRecord
  validates_inclusion_of :ad_type, :in => %w(horizontal vertical)
  validates_presence_of :image_url, :referral_url, :ad_type, :status, :width, :height

  def self.random(type = "vertical")
    where(:ad_type => type, :status => "active").order(Arel.sql("random()")).take
  end

  def self.reset_hit_count(ids)
    where(:id => ids).update_all(:hit_count => 0)
  end

  # virtual method for resetting hit count in view
  def reset_hit_count=(is_reset)
    self.hit_count = 0 if is_reset == "1"
  end

  # virtual method for no-reset default in view's form
  def reset_hit_count
    "0"
  end
end
