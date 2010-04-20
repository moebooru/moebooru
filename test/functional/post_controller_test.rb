require File.dirname(__FILE__) + '/../test_helper'

class PostControllerTest < ActionController::TestCase
  fixtures :users

  def create_post(tags, post_number = 1, params = {})
    Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{post_number}.jpg")}.merge(params))
  end
  
  def update_post(post, params = {})
    post.update_attributes({:updater_user_id => 1, :updater_ip_addr => '127.0.0.1'}.merge(params))
  end
  
  def create_default_posts
    p1 = create_post("tag1", 1)
    p2 = create_post("tag2", 2)
    p3 = create_post("tag3", 3)
    p4 = create_post("tag4", 4)
    [p1, p2, p3, p4]
  end
  
  def test_create
    get :upload, {}, {:user_id => 3}
    assert_response :success
    
    post :create, {:post => {:source => "", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test1.jpg"), :tags => "hoge", :rating => "Safe"}}
    p = Post.find(:first, :order => "id DESC")
    assert_equal("hoge", p.cached_tags)
    assert_equal("jpg", p.file_ext)
    assert_equal("s", p.rating)
    assert_equal(3, p.user_id)
    assert_equal(true, File.exists?(p.file_path))
    assert_equal(true, File.exists?(p.preview_path))
    
    # TODO: test duplicates
    # TODO: test privileges
    # TODO: test daily limits
  end
  
  def test_moderate
    p1 = create_post("hoge", 1, :status => "pending")
    p2 = create_post("hoge", 2)
    p3 = create_post("moge", 3)
    
    p2.flag!("sage", 1)

    get :moderate, {}, {:user_id => 1}
    assert_response :success

    get :moderate, {:query => "moge"}, {:user_id => 1}
    assert_response :success
    
    post :moderate, {:ids => {p1.id => "1"}, :commit => "Approve"}, {:user_id => 1}
    p1.reload
    assert_equal("active", p1.status)

    post :moderate, {:ids => {p2.id => "1"}, :reason => "sage", :commit => "Delete"}, {:user_id => 1}
    p2.reload
    assert_equal("deleted", p2.status)
    assert_not_nil(p2.flag_detail)
    assert_equal("sage", p2.flag_detail.reason)
  end
  
  def test_update
    p1 = create_post("hoge", 1)
    
    post :update, {:post => {:tags => "moge", :rating => "Explicit"}, :id => p1.id}, {:user_id => 3}
    p1.reload
    assert_equal("moge", p1.cached_tags)
    assert_equal("e", p1.rating)
  end
  
  def test_destroy
    p1 = create_post("hoge", 1, :user_id => 3)
    
    get :delete, {:id => p1.id}, {:user_id => 3}
    assert_response :success
    
    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 4}
    assert_redirected_to :controller => "user", :action => "login"
    p1.reload
    assert_equal("active", p1.status)
    
    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 3}
    assert_redirected_to :controller => "user", :action => "login"
    p1.reload
    assert_equal("active", p1.status)
    
    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 1}
    p1.reload
    assert_equal("deleted", p1.status)
    assert_not_nil(p1.flag_detail)
    assert_equal("sage", p1.flag_detail.reason)

    post :destroy, {:id => p1.id, :reason => "sage"}, {:user_id => 1}
    assert_nil(Post.find_by_id(p1.id))
  end
  
  def test_deleted_index
    get :deleted_index, {}, {:user_id => 3}
    assert_response :success
    
    get :deleted_index, {:user_id => 1}, {:user_id => 3}
    assert_response :success
  end
  
  def test_index
    create_default_posts
    
    get :index, {}, {:user_id => 3}
    assert_response :success
    
    get :index, {:tags => "tag1"}, {:user_id => 3}
    assert_response :success
    
    get :index, {:format => "json"}, {:user_id => 3}
    assert_response :success
    
    get :index, {:format => "xml"}, {:user_id => 3}
    assert_response :success
  end
  
  def test_atom
    create_default_posts
    
    get :atom, {}, {:user_id => 3}
    assert_response :success
    
    get :atom, {:tags => "tag1"}, {:user_id => 3}
    assert_response :success
  end
  
  def test_piclens
    create_default_posts
    
    get :piclens, {}, {:user_id => 3}
    assert_response :success
    
    get :piclens, {:tags => "tag1"}, {:user_id => 3}
    assert_response :success
  end
  
  def test_show
    get :show, {:id => 1}, {:user_id => 3}
    assert_response :success
  end
  
  def test_popular
    get :popular_by_day, {}, {:user_id => 3}
    assert_response :success
  end
  
  def test_revert_tags
    p1 = create_post("tag1", 1)
    update_post(p1, :tags => "hoge")
    update_post(p1, :tags => "moge")
    
    history_id = p1.tag_history[-1].id
    
    post :revert_tags, {:id => p1.id, :history_id => history_id}, {:user_id => 3}
    p1.reload
    assert_equal("tag1", p1.cached_tags)
  end
  
  def test_vote
    p1 = create_post("tag1", 1)
    
    post :vote, {:id => p1.id, :score => 1}, {:user_id => 3}
    p1.reload
    assert_equal(1, p1.score)
    
    p2 = create_post("tag2", 2)

    post :vote, {:id => p2.id, :score => 5}, {:user_id => 3}
    p2.reload
    assert_equal(0, p2.score)
  end
  
  def test_flag
    p1 = create_post("tag1", 1)
    
    post :flag, {:id => p1.id, :reason => "sage"}, {:user_id => 3}
    
    p1.reload
    assert_equal("flagged", p1.status)
    assert_not_nil(p1.flag_detail)
    assert_equal("sage", p1.flag_detail.reason)
  end
  
  def test_random
    get :random, {}, {:user_id => 3}
    assert_response :redirect
  end
  
  def test_undelete
    p1 = create_post("tag1", 1, :status => "deleted")
    
    post :undelete, {:id => p1.id}, {:user_id => 2}
    
    p1.reload
    assert_equal("active", p1.status)
  end
end
