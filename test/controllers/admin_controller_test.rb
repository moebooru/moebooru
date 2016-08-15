require "test_helper"

class AdminControllerTest < ActionController::TestCase
  fixtures :users

  def setup_action_mailer
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  def test_index
    get :index, :session => { :user_id => 1 }
    assert_response :success
  end

  def test_edit_user
    get :edit_user, :session => { :user_id => 1 }
    assert_response :success

    post :edit_user, :params => { :user => { :name => "admin", :level => 10 } }, :session => { :user_id => 1 }
    assert_equal(10, User.find(1).level)
  end

  def test_reset_password
    setup_action_mailer

    get :reset_password, :params => { :user => { :name => "admin" } }, :session => { :user_id => 1 }
    assert_response :success

    admin = User.find(1)
    old_password_hash = admin.password_hash

    post :reset_password, :params => { :user => { :name => "admin" } }, :session => { :user_id => 1 }
    admin.reload
    assert_not_equal(old_password_hash, admin.password_hash)
  end
end
