require File.dirname(__FILE__) + '/../test_helper'

class UserRecordTest < ActiveSupport::TestCase
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
  end
  
  def create_user(name, params = {})
    user = User.new({:password => "zugzug1", :password_confirmation => "zugzug1", :email => "#{name}@danbooru.com"}.merge(params))
    user.name = name
    user.level = CONFIG["user_levels"]["Member"]
    user.save
    user
  end

  def test_all
    dmail = UserRecord.create(:body => "bad", :user => "member", :reported_by => 1, :is_positive => true)
    assert_equal(4, dmail.user_id)
    assert_not_nil(Dmail.find_by_body("admin created a positive record for your account. <a href=\"/user_record/index?user_id=4\">View your record</a>."))
  end
end
