require File.dirname(__FILE__) + '/../test_helper'

class BanTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
    
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def test_all
    ban = Ban.create(:user_id => 4, :banned_by => 1, :reason => "hoge", :duration => "3")
    assert_equal(CONFIG["user_levels"]["Blocked"], User.find(4).level)
    assert_not_nil(UserRecord.find_by_user_id(4))
    assert_equal("Blocked: hoge", UserRecord.find_by_user_id(4).body)
    ban.destroy
    assert_equal(20, User.find(4).level)
  end
end
