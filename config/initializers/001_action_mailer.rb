ActionMailer::Base.default_charset = "utf-8"
#ActionMailer::Base.delivery_method = :sendmail
ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.perform_deliveries = true

ActionMailer::Base.smtp_settings = {
  :address => "localhost",
  :port => 25,
  :domain => CONFIG["server_host"]
}
