require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def create_user(name, params = {})
    user = User.new({ :password => "zugzug1", :password_confirmation => "zugzug1", :email => "#{name}@danbooru.com" }.merge(params))
    user.name = name
    user.level = CONFIG["user_levels"]["Member"]
    user.save
    user
  end

  # def test_confirmation_email
  #   user = create_user("bob")
  #   assert_nothing_raised {UserMailer.deliver_confirmation_email(user)}
  #   assert_not_equal(0, ActionMailer::Base.deliveries.size)
  #   assert_equal("From: #{CONFIG['admin_contact']}\r\nTo: bob@danbooru.com\r\nSubject: #{CONFIG['app_name']} - Confirm email address\r\nMime-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>Hello, bob. You need to activate your account by visiting <a href=\"http://#{CONFIG['server_host']}/user/activate_user?hash=#{User.confirmation_hash('bob')}\">this link</a>.</p>\n", ActionMailer::Base.deliveries[0].encoded)
  # end

  def test_new_password
    user = create_user("bob")
    assert_nothing_raised { UserMailer.new_password(user, "zugzug2").deliver_now }
    assert_emails 1
    assert_equal [CONFIG["email_from"]], ActionMailer::Base.deliveries[0].from
    assert_equal [user.email], ActionMailer::Base.deliveries[0].to
    assert_equal "#{CONFIG["app_name"]} - Password Reset", ActionMailer::Base.deliveries[0].subject
    assert_match /Your password has been reset to/, ActionMailer::Base.deliveries[0].body.parts.first.decoded
  end

  def test_dmail
    sender = User.find(1)
    receiver = User.find(2)
    assert_nothing_raised { UserMailer.dmail(receiver, sender, "test title", "test body").deliver_now }
    assert_emails 1
    assert_equal [CONFIG["email_from"]], ActionMailer::Base.deliveries[0].from
    assert_equal [receiver.email], ActionMailer::Base.deliveries[0].to
    assert_equal "#{CONFIG["app_name"]} - Message received from admin", ActionMailer::Base.deliveries[0].subject
    assert_match /admin said:/, ActionMailer::Base.deliveries[0].body.decoded
  end
end
