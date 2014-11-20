# Sends email to future!
# Or not. It sends dmail.
class DMailer
  def self.user_record_notification(user_record)
    url = Rails.application.routes.url_helpers.url_for :controller => :user_record, :action => :index, :user_id => user_record.user_id, :host => CONFIG["server_host"]
    body = "#{user_record.reporter.name} created a #{user_record.is_positive? ? "positive" : "negative"} record for your account. <<#{url}|View your record>>."
    Dmail.create(:from_id => user_record.reported_by, :to_id => user_record.user_id, :title => "Your user record has been updated", :body => body)
  end
end
