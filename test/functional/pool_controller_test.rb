require File.dirname(__FILE__) + '/../test_helper'

class PoolControllerTest < ActionController::TestCase
  fixtures :users, :posts
  
  def create_pool(name, params = {})
    Pool.create({:name => name, :user_id => 1, :is_public => false, :description => "hoge"}.merge(params))
  end
  
  def create_post(tags, post_number, params = {})
    Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{post_number}.jpg")}.merge(params))
  end
  
  def test_index
    pool = create_pool("hoge")

    get :index, {}, {:user_id => 1}
    assert_response :success
    
    get :index, {:query => "hoge"}, {:user_id => 1}
    assert_response :success
  end
  
  def test_show
    pool = create_pool("hoge")
    pool.add_post(1)
    pool.add_post(2)
    
    get :show, {:id => pool.id}, {:user_id => 1}
    assert_response :success
  end
  
  def test_update
    pool = create_pool("hoge")
    
    get :update, {:id => pool.id}, {:user_id => 1}
    assert_response :success
    
    post :update, {:id => pool.id, :pool => {:is_public => true, :name => "moogle"}}, {:user_id => 1}
    assert_redirected_to :action => "show", :id => pool.id
    pool.reload
    assert_equal(true, pool.is_public?)
    assert_equal("moogle", pool.name)
  end
  
  def test_create
    get :create, {}, {:user_id => 1}
    assert_response :success
    
    post :create, {:pool => {:name => "moge", :is_public => "1", :description => "moge moge moge"}}, {:user_id => 1}
    pool = Pool.find_by_name("moge")
    assert_redirected_to :action => "show", :id => pool.id
    assert_not_nil(pool)
    assert_equal(true, pool.is_public?)
    assert_equal("moge moge moge", pool.description)
    assert_equal(1, pool.user_id)
  end
  
  def test_destroy
    pool = create_pool("hoge")
    
    get :destroy, {:id => pool.id}, {:user_id => 1}
    assert_response :success
    
    post :destroy, {:id => pool.id}, {:user_id => 1}
    assert_redirected_to :action => "index"
    assert_nil(Pool.find_by_name("hoge"))
  end
  
  def test_add_post_to_inactive_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 3, :is_active => false)
    
    get :add_post, {:post_id => 1}
    assert_equal(false, assigns(:pools).any? {|x| x.name == "hoge"})
  end
  
  def test_add_post_to_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 3)
    
    # Test as anonymous
    get :add_post, {:post_id => 1}
    assert_response :success
    
    get :add_post, {:post_id => 1}, {:user_id => 4}
    assert_response :success
    
    post :add_post, {:post_id => 1, :pool_id => pool.id, :pool => {}}, {:user_id => 4}
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_equal(1, PoolPost.count(:conditions => ["post_id = ? AND pool_id = ?", 1, pool.id]))
    
    post :add_post, {:post_id => 1, :pool_id => pool.id, :pool => {}}, {:user_id => 4}
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_equal(1, PoolPost.count(:conditions => ["post_id = ? AND pool_id = ?", 1, pool.id]))    
  end
  
  def test_add_post_to_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 3)
    
    # Test as anonymous
    get :add_post, {:post_id => 1}
    assert_response :success
    
    get :add_post, {:post_id => 1}, {:user_id => 4}
    assert_response :success
    
    post :add_post, {:post_id => 1, :pool_id => pool.id, :pool => {}}, {:user_id => 4}
    assert_redirected_to :controller => "user", :action => "login"
    assert_equal(0, PoolPost.count(:conditions => ["post_id = ? AND pool_id = ?", 1, pool.id]))

    post :add_post, {:post_id => 1, :pool_id => pool.id, :pool => {}}, {:user_id => 3}
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_equal(1, PoolPost.count(:conditions => ["post_id = ? AND pool_id = ?", 1, pool.id]))
  end
  
  def test_remove_post_from_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 3)
    pool.add_post(1)
    
    # Don't have an HTML page for this
    post :remove_post, {:format => "json", :post_id => 1, :pool_id => pool.id}, {:user_id => 4}
    assert_response :success
    assert_equal(0, PoolPost.count(:conditions => ["post_id = ? AND pool_id = ?", 1, pool.id]))
  end
  
  def test_remove_post_from_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 3)
    pool.add_post(1)

    # Don't have an HTML page for this
    post :remove_post, {:format => "json", :post_id => 1, :pool_id => pool.id}, {:user_id => 4}
    assert_response 403
    assert_equal(1, PoolPost.count(:conditions => ["post_id = ? AND pool_id = ?", 1, pool.id]))

    post :remove_post, {:format => "json", :post_id => 1, :pool_id => pool.id}, {:user_id => 3}
    assert_response :success
    assert_equal(0, PoolPost.count(:conditions => ["post_id = ? AND pool_id = ?", 1, pool.id]))
  end
  
  def test_order_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 3)
    pool.add_post(1)
    pool.add_post(2)
    
    get :order, {:id => pool.id}
    assert_response :success
    
    get :order, {:id => pool.id}, {:user_id => 4}
    assert_response :success

    get :order, {:id => pool.id, :query => "tag1"}, {:user_id => 4}
    assert_response :success
    
    pp1 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 1, pool.id])
    pp2 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 2, pool.id])
    post :order, {:id => pool.id, :pool_post_sequence => {pp1.id => "10", pp2.id => "20"}, :posts => {"1" => "1", "2" => "1"}}, {:user_id => 4}
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 1, pool.id])
    pp2 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 2, pool.id])
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
    assert_equal(10, pp1.sequence)
    assert_equal(20, pp2.sequence)
  end
  
  def test_order_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 3)
    pool.add_post(1)
    pool.add_post(2)
    
    get :order, {:id => pool.id}
    assert_redirected_to :controller => "user", :action => "login"
    
    get :order, {:id => pool.id}, {:user_id => 4}
    assert_redirected_to :controller => "user", :action => "login"

    get :order, {:id => pool.id, :query => "tag1"}, {:user_id => 4}
    assert_redirected_to :controller => "user", :action => "login"
    
    pp1 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 1, pool.id])
    pp2 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 2, pool.id])
    post :order, {:id => pool.id, :pool_post_sequence => {pp1.id => "10", pp2.id => "20"}, :posts => {"1" => "1", "2" => "1"}}, {:user_id => 4}
    assert_redirected_to :controller => "user", :action => "login"
    
    post :order, {:id => pool.id, :pool_post_sequence => {pp1.id => "10", pp2.id => "20"}, :posts => {"1" => "1", "2" => "1"}}, {:user_id => 3}
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 1, pool.id])
    pp2 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 2, pool.id])
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
    assert_equal(10, pp1.sequence)
    assert_equal(20, pp2.sequence)
  end
  
  def test_import_to_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 4)
    p1 = create_post("tag1", 1)
    p2 = create_post("tag2", 2)
    
    get :import, {:id => pool.id}
    assert_redirected_to :controller => "user", :action => "login"
    
    get :import, {:id => pool.id}, {:user_id => 3}
    assert_redirected_to :controller => "user", :action => "login"
    
    post :import, {:id => pool.id, :posts => {"1" => "1", "2" => "2"}}, {:user_id => 3}
    assert_redirected_to :controller => "user", :action => "login"
    pp1 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 1, pool.id])
    pp2 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 2, pool.id])
    assert_nil(pp1)
    assert_nil(pp2)
    
    post :import, {:id => pool.id, :posts => {"1" => "1", "2" => "2"}}, {:user_id => 4}
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 1, pool.id])
    pp2 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 2, pool.id])
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
  end
  
  def test_import_to_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 4)
    p1 = create_post("tag1", 1)
    p2 = create_post("tag2", 2)
    
    get :import, {:id => pool.id, :format => "js"}
    assert_response :success
    
    get :import, {:id => pool.id, :format => "js"}, {:user_id => 3}
    assert_response :success
    
    post :import, {:id => pool.id, :posts => {"1" => "1", "2" => "2"}}, {:user_id => 3}
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 1, pool.id])
    pp2 = PoolPost.find(:first, :conditions => ["post_id = ? AND pool_id = ?", 2, pool.id])
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
  end
  
  def test_select
    pool = create_pool("hoge", :is_public => true, :user_id => 4)
    
    get :select, {:post_id => 1}
    assert_response :success
    
    get :select, {:post_id => 1}, {:user_id => 4}
    assert_response :success
    
    pool.update_attributes(:is_active => false)
    
    get :select, {:post_id => 1}
    assert_equal(false, assigns(:pools).any? {|x| x.name == "hoge"})
  end
end
