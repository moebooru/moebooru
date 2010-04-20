require File.dirname(__FILE__) + '/../test_helper'

class UserControllerTest < ActionController::TestCase
  fixtures :users, :table_data
  
  def setup_action_mailer
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end
  
  def create_user(name, params = {})
    user = User.new({:password => "zugzug1", :password_confirmation => "zugzug1", :email => "a@b.net"}.merge(params))
    user.name = name
    user.level = CONFIG["user_levels"]["Member"]
    user.save
    user
  end
  
  def test_show
    get :show, {:id => 1}
    assert_response :success
  end
  
  def test_invites
    setup_action_mailer
    
    member = User.find(4)
    
    # Should fail
    post :invites, {:member => {:name => "member", :level => 33}}, {:user_id => 2}
    member.reload
    assert_equal(CONFIG["user_levels"]["Member"], member.level)    
    
    # Should fail
    mod = User.find(2)
    mod.invite_count = 10
    mod.save
    ur = UserRecord.create(:user_id => 4, :is_positive => false, :body => "bad", :reported_by => 1)    
    post :invites, {:member => {:name => "member", :level => 33}}, {:user_id => 2}
    member.reload
    assert_equal(CONFIG["user_levels"]["Member"], member.level)    

    ur.destroy

    # Should succeed
    post :invites, {:member => {:name => "member", :level => 50}}, {:user_id => 2}
    member.reload
    assert_equal(CONFIG["user_levels"]["Contributor"], member.level)
  end
  
  def test_home
    get :home, {}, {}
    assert_response :success
    
    get :home, {}, {:user_id => 1}
    assert_response :success
  end
  
  def test_index
    get :index, {}, {}
    assert_response :success

    # TODO: more parameters
  end
  
  def test_authentication_failure
    user = create_user("bob")
    
    get :login, {}, {}
    assert_response :success
    
    post :authenticate, {:user => {:name => "bob", :password => "zugzug2"}, :url => "http://google.com"}, {}
    assert_not_nil(assigns(:current_user))
    assert_equal(true, assigns(:current_user).is_anonymous?)
  end
  
  def test_authentication_success
    user = create_user("bob")

    post :authenticate, {:user => {:name => "bob", :password => "zugzug1"}, :url => "http://google.com"}, {}
    assert_not_nil(assigns(:current_user))
    assert_equal(false, assigns(:current_user).is_anonymous?)
    assert_equal("bob", assigns(:current_user).name)
  end
  
  def test_create
    setup_action_mailer
    
    get :signup, {}, {}
    assert_response :success
    
    post :create, {:user => {:name => "mog", :email => "mog@danbooru.com", :password => "zugzug1", :password_confirmation => "zugzug1"}}
    mog = User.find_by_name("mog")
    assert_not_nil(mog)
    
    if CONFIG["enable_account_email_activation"]
      assert_equal(CONFIG["user_levels"]["Unactivated"], mog.level)      
      assert_equal(1, ActionMailer::Base.deliveries.size)
      
      post :activate_user, {:hash => User.confirmation_hash("mog")}
      mog.reload
      assert_equal(CONFIG["user_levels"]["Member"], mog.level)
    end
  end
    
  def test_update
    get :edit, {}, {:user_id => 4}
    assert_response :success

    post :update, {:user => {:invite_count => 10, :receive_dmails => true}}, {:user_id => 4}
    user = User.find(4)
    assert_equal(0, user.invite_count)
    assert_equal(true, user.receive_dmails?)
  end
  
  def test_update_favorite_tags
    post :update, {:user => {:favorite_tags_text => "a b c"}}, {:user_id => 4}
    user = User.find(4)
    assert_equal("a b c", user.favorite_tags_text)
    
    post :update, {:user => {:favorite_tags_text => "c d e"}}, {:user_id => 4}
    user.reload
    assert_equal("c d e", user.favorite_tags_text)    
  end
  
  def test_reset_password
    setup_action_mailer
    
    old_password_hash = User.find(1).password_hash
    
    get :reset_password
    assert_response :success
    
    post :reset_password, {:user => {:name => "admin", :email => "wrong@danbooru.com"}}
    assert_equal(old_password_hash, User.find(1).password_hash)

    post :reset_password, {:user => {:name => "admin", :email => "admin@danbooru.com"}}
    assert_not_equal(old_password_hash, User.find(1).password_hash)
  end
  
  def test_block
    setup_action_mailer
    
    get :block, {:id => 4}, {:user_id => 1}
    assert_response :success
    
    post :block, {:id => 4, :ban => {:reason => "bad", :duration => 5}}, {:user_id => 1}
    banned = User.find(4)
    assert_equal(CONFIG["user_levels"]["Blocked"], banned.level)
    
    get :show_blocked_users, {}, {:user_id => 1}
    assert_response :success
    
    post :unblock, {:user => {"4" => "1"}}, {:user_id => 1}
    banned.reload
    assert_equal(CONFIG["user_levels"]["Member"], banned.level)
  end
  
  if CONFIG["enable_account_email_activation"]
    def test_resend_confirmation
      setup_action_mailer
      
      get :resend_confirmation, {}, {}
      assert_response :success
      
      post :resend_confirmation, {:email => "unactivated@danbooru.com"}
      assert_equal(1, ActionMailer::Base.deliveries.size)
    end
  end
end
