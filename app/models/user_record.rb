class UserRecord < ActiveRecord::Base
  belongs_to :user
  belongs_to :reporter, :foreign_key => "reported_by", :class_name => "User"
  validates_presence_of :user_id
  validates_presence_of :reported_by
  after_save :generate_dmail
  
  def user=(name)
    self.user_id = User.find_by_name(name).id rescue nil
  end
  
  def generate_dmail
    body = "#{reporter.name} created a #{is_positive? ? 'positive' : 'negative'} record for your account. <a href=\"/user_record/index?user_id=#{user_id}\">View your record</a>."
    
    Dmail.create(:from_id => reported_by, :to_id => user_id, :title => "Your user record has been updated", :body => body)
  end
end
