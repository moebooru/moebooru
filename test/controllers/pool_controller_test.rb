require "test_helper"

class PoolControllerTest < ActionController::TestCase
  fixtures :users, :posts

  def create_pool(name, params = {})
    Pool.create({ :name => name, :user_id => 1, :is_public => false, :description => "hoge" }.merge(params))
  end

  def create_post(tags, post_number, params = {})
    Thread.current["danbooru-user_id"] = 1
    Post.create({ :user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => "127.0.0.1", :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_file("#{Rails.root}/test/mocks/test/test#{post_number}.jpg") }.merge(params))
  end

  def test_index
    create_pool("hoge")

    get :index, :session => { :user_id => 1 }
    assert_response :success

    get :index, :params => { :query => "hoge" }, :session => { :user_id => 1 }
    assert_response :success
  end

  def test_show
    pool = create_pool("hoge")
    pool.add_post(1)
    pool.add_post(2)

    get :show, :params => { :id => pool.id }, :session => { :user_id => 1 }
    assert_response :success
  end

  def test_update
    pool = create_pool("hoge")

    get :update, :params => { :id => pool.id }, :session => { :user_id => 1 }
    assert_response :success

    post :update, :params => { :id => pool.id, :pool => { :is_public => true, :name => "moogle" } }, :session => { :user_id => 1 }
    assert_redirected_to :action => "show", :id => pool.id
    pool.reload
    assert_equal(true, pool.is_public?)
    assert_equal("moogle", pool.name)
  end

  def test_create
    get :create, :session => { :user_id => 1 }
    assert_response :success

    post :create, :params => { :pool => { :name => "moge", :is_public => "1", :description => "moge moge moge" } }, :session => { :user_id => 1 }
    pool = Pool.find_by_name("moge")
    assert_redirected_to :action => "show", :id => pool.id
    assert_not_nil(pool)
    assert_equal(true, pool.is_public?)
    assert_equal("moge moge moge", pool.description)
    assert_equal(1, pool.user_id)
  end

  def test_destroy
    pool = create_pool("hoge")

    get :destroy, :params => { :id => pool.id }, :session => { :user_id => 1 }
    assert_response :success

    post :destroy, :params => { :id => pool.id }, :session => { :user_id => 1 }
    assert_redirected_to :action => "index"
    assert_nil(Pool.find_by_name("hoge"))
  end

  def test_add_post_to_inactive_pool
    create_pool("hoge", :is_public => true, :user_id => 3, :is_active => false)

    get :add_post, :params => { :post_id => 1 }, :session => { :user_id => 4 }
    assert_equal(false, assigns(:pools).any? { |x| x.name == "hoge" })
  end

  def test_add_post_to_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 3)

    # Test as anonymous
    get :add_post, :params => { :post_id => 1 }
    assert_redirected_to :controller => "user", :action => "login", :url => "/pool/add_post?post_id=1"

    get :add_post, :params => { :post_id => 1 }, :session => { :user_id => 4 }
    assert_response :success

    post :add_post, :params => { :post_id => 1, :pool_id => pool.id, :pool => {} }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_equal(1, PoolPost.where(:post_id => 1, :pool_id => pool.id).count)

    post :add_post, :params => { :post_id => 1, :pool_id => pool.id, :pool => {} }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_equal(1, PoolPost.where(:post_id => 1, :pool_id => pool.id).count)
  end

  def test_add_post_to_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 3)

    # Test as anonymous
    get :add_post, :params => { :post_id => 1 }
    assert_redirected_to :controller => "user", :action => "login", :url => "/pool/add_post?post_id=1"

    get :add_post, :params => { :post_id => 1 }, :session => { :user_id => 4 }
    assert_response :success

    post :add_post, :params => { :post_id => 1, :pool_id => pool.id, :pool => {} }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "user", :action => "login"
    assert_equal(0, PoolPost.where(:active => true, :post_id => 1, :pool_id => pool.id).count)

    post :add_post, :params => { :post_id => 1, :pool_id => pool.id, :pool => {} }, :session => { :user_id => 3 }
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_equal(1, PoolPost.where(:active => true, :post_id => 1, :pool_id => pool.id).count)
  end

  def test_remove_post_from_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 3)
    pool.add_post(1)

    # Don't have an HTML page for this
    post :remove_post, :params => { :format => "json", :post_id => 1, :pool_id => pool.id }, :session => { :user_id => 4 }
    assert_response :success
    assert_equal(0, PoolPost.where(:active => true, :post_id => 1, :pool_id => pool.id).count)
  end

  def test_remove_post_from_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 3)
    pool.add_post(1)

    # Don't have an HTML page for this
    post :remove_post, :params => { :format => "json", :post_id => 1, :pool_id => pool.id }, :session => { :user_id => 4 }
    assert_response :forbidden
    assert_equal(1, PoolPost.where(:active => true, :post_id => 1, :pool_id => pool.id).count)

    post :remove_post, :params => { :format => "json", :post_id => 1, :pool_id => pool.id }, :session => { :user_id => 3 }
    assert_response :success
    assert_equal(0, PoolPost.where(:active => true, :post_id => 1, :pool_id => pool.id).count)
  end

  def test_order_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 3)
    pool.add_post(1)
    pool.add_post(2)

    get :order, :params => { :id => pool.id }
    assert_response :success

    get :order, :params => { :id => pool.id }, :session => { :user_id => 4 }
    assert_response :success

    get :order, :params => { :id => pool.id, :query => "tag1" }, :session => { :user_id => 4 }
    assert_response :success

    pp1 = PoolPost.where(:post_id => 1, :pool_id => pool.id).first
    pp2 = PoolPost.where(:post_id => 2, :pool_id => pool.id).first
    post :order, :params => { :id => pool.id, :pool_post_sequence => { pp1.id => "10", pp2.id => "20" }, :posts => { "1" => "1", "2" => "1" } }, :session => { :user_id => 4 }
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.where(:post_id => 1, :pool_id => pool.id).first
    pp2 = PoolPost.where(:post_id => 2, :pool_id => pool.id).first
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
    assert_equal("10", pp1.sequence)
    assert_equal("20", pp2.sequence)
  end

  def test_order_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 3)
    pool.add_post(1)
    pool.add_post(2)

    get :order, :params => { :id => pool.id }
    assert_redirected_to :controller => "user", :action => "login", :url => "/pool/order/#{pool.id}"

    get :order, :params => { :id => pool.id }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "user", :action => "login", :url => "/pool/order/#{pool.id}"

    get :order, :params => { :id => pool.id, :query => "tag1" }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "user", :action => "login", :url => "/pool/order/#{pool.id}?query=tag1"

    pp1 = PoolPost.where(:post_id => 1, :pool_id => pool.id).first
    pp2 = PoolPost.where(:post_id => 2, :pool_id => pool.id).first
    post :order, :params => { :id => pool.id, :pool_post_sequence => { pp1.id => "10", pp2.id => "20" }, :posts => { "1" => "1", "2" => "1" } }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "user", :action => "login"

    post :order, :params => { :id => pool.id, :pool_post_sequence => { pp1.id => "10", pp2.id => "20" }, :posts => { "1" => "1", "2" => "1" } }, :session => { :user_id => 3 }
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.where(:post_id => 1, :pool_id => pool.id).first
    pp2 = PoolPost.where(:post_id => 2, :pool_id => pool.id).first
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
    assert_equal("10", pp1.sequence)
    assert_equal("20", pp2.sequence)
  end

  def test_import_to_private_pool
    pool = create_pool("hoge", :is_public => false, :user_id => 4)
    create_post("tag1", 1)
    create_post("tag2", 2)

    get :import, :params => { :id => pool.id }
    assert_redirected_to :controller => "user", :action => "login", :url => "/pool/import/#{pool.id}"

    get :import, :params => { :id => pool.id }, :session => { :user_id => 3 }
    assert_redirected_to :controller => "user", :action => "login", :url => "/pool/import/#{pool.id}"

    post :import, :params => { :id => pool.id, :posts => { "1" => "1", "2" => "2" } }, :session => { :user_id => 3 }
    assert_redirected_to :controller => "user", :action => "login"
    pp1 = PoolPost.where(:post_id => 1, :pool_id => pool.id).first
    pp2 = PoolPost.where(:post_id => 2, :pool_id => pool.id).first
    assert_nil(pp1)
    assert_nil(pp2)

    post :import, :params => { :id => pool.id, :posts => { "1" => "1", "2" => "2" } }, :session => { :user_id => 4 }
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.where(:post_id => 1, :pool_id => pool.id).first
    pp2 = PoolPost.where(:post_id => 2, :pool_id => pool.id).first
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
  end

  def test_import_to_public_pool
    pool = create_pool("hoge", :is_public => true, :user_id => 4)
    create_post("tag1", 1)
    create_post("tag2", 2)

    get :import, :xhr => true, :params => { :id => pool.id, :format => "js" }, :session => { :user_id => 3 }
    assert_response :success

    post :import, :params => { :id => pool.id, :posts => { "1" => "1", "2" => "2" } }, :session => { :user_id => 3 }
    assert_redirected_to :action => "show", :id => pool.id
    pp1 = PoolPost.where(:post_id => 1, :pool_id => pool.id).first
    pp2 = PoolPost.where(:post_id => 2, :pool_id => pool.id).first
    assert_not_nil(pp1)
    assert_not_nil(pp2)
    assert_nil(pp1.prev_post_id)
    assert_equal(2, pp1.next_post_id)
    assert_equal(1, pp2.prev_post_id)
    assert_nil(pp2.next_post_id)
  end

  def test_select
    pool = create_pool("hoge", :is_public => true, :user_id => 4)

    get :select, :params => { :post_id => 1 }
    assert_response :success

    get :select, :params => { :post_id => 1 }, :session => { :user_id => 4 }
    assert_response :success

    pool.update(:is_active => false)

    get :select, :params => { :post_id => 1 }
    assert_equal(false, assigns(:pools).any? { |x| x.name == "hoge" })
  end
end
