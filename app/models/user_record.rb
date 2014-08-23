class UserRecord < ActiveRecord::Base
  belongs_to :user
  belongs_to :reporter, :foreign_key => "reported_by", :class_name => "User"
  validates_presence_of :user_id
  validates_presence_of :reported_by

  def user=(name)
    self.user_id = User.find_by_name(name).id rescue nil
  end
end
