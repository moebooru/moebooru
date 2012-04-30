class Advertisement < ActiveRecord::Base
  validates_inclusion_of :ad_type, :in => %w(horizontal vertical)

  def self.random(type = 'vertical')
    self.find(:first, :conditions => { :ad_type => type, :status => 'active' }, :order => 'random()')
  end
end
