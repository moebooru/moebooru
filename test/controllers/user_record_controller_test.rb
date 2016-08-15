require "test_helper"

class UserRecordControllerTest < ActionController::TestCase
  fixtures :users

  def setup_action_mailer
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def test_all
    setup_action_mailer

    get :create, :params => { :user_id => 1 }, :session => { :user_id => 3 }
    assert_response :success

    post :create, :params => { :user_id => 3, :user_record => { :is_positive => false, :body => "hella" } }, :session => { :user_id => 3 }
    assert_equal(0, UserRecord.count)

    post :create, :params => { :user_id => 1, :user_record => { :is_positive => false, :body => "hella" } }, :session => { :user_id => 3 }
    assert_equal(1, UserRecord.count)

    get :index, :session => { :user_id => 3 }
    assert_response :success

    ur = UserRecord.first

    post :destroy, :params => { :id => ur.id }, :session => { :user_id => 4 }
    assert_equal(1, UserRecord.count)

    post :destroy, :params => { :id => ur.id }, :session => { :user_id => 3 }
    assert_equal(0, UserRecord.count)

    post :create, :params => { :user_id => 1, :user_record => { :is_positive => false, :body => "hella" } }, :session => { :user_id => 3 }
    ur = UserRecord.first
    post :destroy, :params => { :id => ur.id }, :session => { :user_id => 1 }
    assert_equal(0, UserRecord.count)
  end
end
