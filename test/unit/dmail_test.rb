require File.dirname(__FILE__) + '/../test_helper'

class DmailTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
    
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def test_mark_as_read
    member = User.find_by_name("member")
    msg1 = Dmail.create(:to_name => "member", :from_name => "admin", :title => "hello", :body => "hello")
    msg2 = Dmail.create(:to_name => "member", :from_name => "admin", :title => "hello", :body => "hello")
    msg3 = Dmail.create(:to_name => "member", :from_name => "admin", :title => "hello", :body => "hello")
    
    member.reload
    assert_equal(true, member.has_mail?)
    
    msg1.mark_as_read!(member)
    msg1.reload
    member.reload
    assert_equal(true, msg1.has_seen?)
    assert_equal(true, member.has_mail?)
    
    msg2.mark_as_read!(member)
    member.reload
    assert_equal(true, member.has_mail?)
    
    msg3.mark_as_read!(member)
    member.reload
    assert_equal(false, member.has_mail?)
  end
  
  def test_all
    msg = Dmail.create(:to_name => "member", :from_name => "admin", :title => "hello", :body => "hello")
    assert_equal(4, msg.to_id)
    assert_equal(1, msg.from_id)
    assert_equal(true, User.find(4).has_mail?)
    assert_equal(1, ActionMailer::Base.deliveries.size)
    assert_equal("From: #{CONFIG['admin_contact']}\r\nTo: member@danbooru.com\r\nSubject: #{CONFIG['app_name']} - Message received from admin\r\nMime-Version: 1.0\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<p>admin said:</p>\n\n<div>\n  <p>hello</p>\n</div>\n", ActionMailer::Base.deliveries[0].encoded)
    
    response_a = Dmail.create(:to_name => "admin", :from_name => "member", :parent_id => msg.id, :title => "hello", :body => "you are wrong")
    assert_equal("Re: hello", response_a.title)
    
    ActionMailer::Base.deliveries = []
    
    Dmail.create(:to_name => "privileged", :from_name => "admin", :title => "hoge", :body => "hoge")
    assert_equal(0, ActionMailer::Base.deliveries.size)
  end
end
