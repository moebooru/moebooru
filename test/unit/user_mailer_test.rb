require File.dirname(__FILE__) + '/../test_helper'

class UserMailerTest < ActiveSupport::TestCase
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
    
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def create_user(name, params = {})
    user = User.new({:password => "zugzug1", :password_confirmation => "zugzug1", :email => "#{name}@danbooru.com"}.merge(params))
    user.name = name
    user.level = CONFIG["user_levels"]["Member"]
    user.save
    user
  end
  
  def test_confirmation_email
    user = create_user("bob")
    assert_nothing_raised {UserMailer.deliver_confirmation_email(user)}
    assert_not_equal(0, ActionMailer::Base.deliveries.size)
    assert_equal("From: #{CONFIG['admin_contact']}\r\nTo: bob@danbooru.com\r\nSubject: #{CONFIG['app_name']} - Confirm email address\r\nMime-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>Hello, bob. You need to activate your account by visiting <a href=\"http://#{CONFIG['server_host']}/user/activate_user?hash=#{User.confirmation_hash('bob')}\">this link</a>.</p>\n", ActionMailer::Base.deliveries[0].encoded)
  end
  
  def test_new_password
    user = create_user("bob")
    assert_nothing_raised {UserMailer.deliver_new_password(user, "zugzug2")}
    assert_not_equal(0, ActionMailer::Base.deliveries.size)
    assert_equal("From: #{CONFIG['admin_contact']}\r\nTo: bob@danbooru.com\r\nSubject: #{CONFIG['app_name']} - Password Reset\r\nMime-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>Hello, bob. Your password has been reset to <code>zugzug2</code>.</p>\n\n<p>You can login to <a href=\"http://#{CONFIG['server_host']}/user/login\">#{CONFIG['app_name']}</a> and change your password to something else.</p>\n", ActionMailer::Base.deliveries[0].encoded)
  end
  
  def test_dmail
    sender = User.find(1)
    receiver = User.find(2)
    assert_nothing_raised {UserMailer.deliver_dmail(sender, receiver, "test title", "test body")}
    assert_not_equal(0, ActionMailer::Base.deliveries.size)
    assert_equal("From: #{CONFIG['admin_contact']}\r\nTo: admin@danbooru.com\r\nSubject: Dev - Message received from mod\r\nMime-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>mod said:</p>\n\n<div>\n  <p>test body</p>\n</div>\n", ActionMailer::Base.deliveries[0].encoded)
  end
end
