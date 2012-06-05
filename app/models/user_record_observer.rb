class UserRecordObserver < ActiveRecord::Observer
  def after_save(user_record)
    DMailer.user_record_notification(user_record)
  end
end
