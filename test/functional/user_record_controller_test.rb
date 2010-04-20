require File.dirname(__FILE__) + '/../test_helper'

class UserRecordControllerTest < ActionController::TestCase
  fixtures :users
  
  def setup_action_mailer
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def test_all
    setup_action_mailer
    
    get :create, {:user_id => 1}, {:user_id => 3}
    assert_response :success
    
    post :create, {:user_id => 3, :user_record => {:is_positive => false, :body => "hella"}}, {:user_id => 3}
    assert_equal(0, UserRecord.count)
    
    post :create, {:user_id => 1, :user_record => {:is_positive => false, :body => "hella"}}, {:user_id => 3}
    assert_equal(1, UserRecord.count)
    
    get :index, {}, {:user_id => 3}
    assert_response :success
    
    ur = UserRecord.find(:first)
    
    post :destroy, {:id => ur.id}, {:user_id => 4}
    assert_equal(1, UserRecord.count)
    
    post :destroy, {:id => ur.id}, {:user_id => 3}
    assert_equal(0, UserRecord.count)

    post :create, {:user_id => 1, :user_record => {:is_positive => false, :body => "hella"}}, {:user_id => 3}
    ur = UserRecord.find(:first)
    post :destroy, {:id => ur.id}, {:user_id => 1}
    assert_equal(0, UserRecord.count)
  end
end
