class ReportMailer < ActionMailer::Base
  default_url_options["host"] = CONFIG["server_host"]

  def moderator_report(email)
    recipients email
    from CONFIG["email_from"]
    subject "#{CONFIG['app_name']} - Moderator Report"
    content_type "text/html"
  end
end
