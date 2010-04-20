require File.dirname(__FILE__) + '/../test_helper'

class TagControllerTest < ActionController::TestCase
  fixtures :users
  
  def create_post(tags, post_number = 1, params = {})
    Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{post_number}.jpg")}.merge(params))
  end
  
  def test_cloud
    create_post("hoge", 1)
    create_post("hoge moge", 2)
    create_post("lodge", 3)
    
    get :cloud, {}, {}
    assert_response :success
  end
  
  def test_index
    create_post("hoge", 1)
    create_post("hoge moge", 2)
    create_post("lodge", 3)

    get :index, {}, {}
    assert_response :success
    
    # TODO: test other params
  end

  def test_mass_edit
    get :mass_edit, {}, {:user_id => 2}
    assert_response :success

    # Can't easily test the mass_edit action. The daemon process does the actual work.
    # Anything we create inside this test is created within a transaction, so any database
    # connection outside of this one won't see any changes. We can disable transactional
    # fixtures but this interferes with other tests. Just assume the action works correctly
    # and test the logic of mass_edit in the unit tests.
  end
  
  def test_edit_preview
    p1 = create_post("hoge", 1)
    p2 = create_post("hoge moge", 2)
    p3 = create_post("lodge", 3)

    get :edit_preview, {:tags => "hoge"}, {:user_id => 2}
    assert_response :success
  end
  
  def test_update
    p1 = create_post("hoge", 1)

    get :edit, {:name => "hoge"}, {:user_id => 3}
    assert_response :success
    
    post :update, {:tag => {:name => "hoge", :tag_type => CONFIG["tag_types"]["Artist"]}}, {:user_id => 3}
    assert_equal(CONFIG["tag_types"]["Artist"], Tag.find_by_name("hoge").tag_type)
  end
  
  def test_related
    p1 = create_post("hoge", 1)
    p2 = create_post("hoge moge", 2)
    p3 = create_post("lodge", 3)
    
    get :related, {:tags => "hoge", :format => "json"}, {}
    assert_response :success
  end
  
  def test_popular
    p1 = create_post("hoge", 1)
    p2 = create_post("hoge moge", 2)
    p3 = create_post("lodge", 3)

    get :popular_by_day, {}, {}
    assert_response :success
    
    get :popular_by_week, {}, {}
    assert_response :success
    
    get :popular_by_month, {}, {}
    assert_response :success
  end
end
