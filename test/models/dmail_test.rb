require "test_helper"

class DmailTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper
  fixtures :users

  def setup
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
    assert_emails 1
    mail = ActionMailer::Base.deliveries.first
    assert_equal [CONFIG["email_from"]], mail.from
    assert_equal %w(member@danbooru.com), mail.to
    assert_equal "#{CONFIG["app_name"]} - Message received from admin", mail.subject
    assert_equal "<p>admin said:</p>\r\n<div>\r\n  <p>Subject: hello</p>\r\n  <hr />\r\n  hello\r\n</div>\r\n", mail.body.raw_source

    response_a = Dmail.create(:to_name => "admin", :from_name => "member", :parent_id => msg.id, :title => "hello", :body => "you are wrong")
    assert_equal("Re: hello", response_a.title)

    ActionMailer::Base.deliveries = []

    Dmail.create(:to_name => "privileged", :from_name => "admin", :title => "hoge", :body => "hoge")
    assert_no_emails
  end
end
