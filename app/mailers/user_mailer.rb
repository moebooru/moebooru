begin
  require "idn"
rescue LoadError
end

class UserMailer < ActionMailer::Base
  helper :application
  default :from => CONFIG["email_from"]

  # def confirmation_email(user)
  #   recipients UserMailer.normalize_address(user.email)
  #   from CONFIG["email_from"]
  #   subject "#{CONFIG["app_name"]} - Confirm email address"
  #   body :user => user
  #   content_type "text/html"
  # end

  def new_password(user, password)
    recipients = UserMailer.normalize_address(user.email)
    subject = "#{CONFIG["app_name"]} - Password Reset"
    @user = user
    @password = password
    mail :to => recipients, :subject => subject
  end

  def dmail(recipient, sender, msg_title, msg_body)
    recipients = UserMailer.normalize_address(recipient.email)
    subject = "#{CONFIG["app_name"]} - Message received from #{sender.name}"
    @body = msg_body
    @sender = sender
    @subject = msg_title
    mail :to => recipients, :subject => subject
  end

  def self.normalize_address(address)
    if defined?(IDN)
      address =~ /\A([^@]+)@(.+)\Z/
      mailbox = Regexp.last_match[1]
      domain = IDN::Idna.toASCII(Regexp.last_match[2])
      "#{mailbox}@#{domain}"
    else
      address
    end
  end
end
