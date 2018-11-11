class UserRecord < ApplicationRecord
  belongs_to :user
  belongs_to :reporter, :foreign_key => "reported_by", :class_name => "User"
  validates_presence_of :user_id
  validates_presence_of :reported_by

  after_save :notify_user

  def user=(name)
    self.user_id = User.find_by(:name => name).try(:id)
  end

  def notify_user
    DMailer.user_record_notification self
  end
end
