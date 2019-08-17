require "test_helper"

class PostControllerTest < ActionController::TestCase
  fixtures :users

  def create_post(tags, post_number = 1, params = {})
    Post.create({ :user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => "127.0.0.1", :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_file("#{Rails.root}/test/mocks/test/test#{post_number}.jpg") }.merge(params))
  end

  def update_post(post, params = {})
    post.update({ :updater_user_id => 1, :updater_ip_addr => "127.0.0.1" }.merge(params))
  end

  def create_default_posts
    p1 = create_post("tag1", 1)
    p2 = create_post("tag2", 2)
    p3 = create_post("tag3", 3)
    p4 = create_post("tag4", 4)
    [p1, p2, p3, p4]
  end

  def test_create
    get :upload, :session => { :user_id => 3 }
    assert_response :success

    post :create, :params => { :post => { :source => "", :file => fixture_file_upload("../mocks/test/test1.jpg"), :tags => "hoge", :rating => "Safe" } }
    p = Post.last
    assert_equal("hoge", p.cached_tags)
    assert_equal("jpg", p.file_ext)
    assert_equal("s", p.rating)
    assert_equal(3, p.user_id)
    assert_equal(true, File.exist?(p.file_path))
    assert_equal(true, File.exist?(p.preview_path))

    # TODO: test duplicates
    # TODO: test privileges
    # TODO: test daily limits
  end

  def test_moderate
    p1 = create_post("hoge", 1, :status => "pending")
    p2 = create_post("hoge", 2)
    create_post("moge", 3)

    p2.flag!("sage", 1)

    get :moderate, :session => { :user_id => 1 }
    assert_response :success

    get :moderate, :params => { :query => "moge" }, :session => { :user_id => 1 }
    assert_response :success

    post :moderate, :params => { :ids => { p1.id => "1" }, :commit => "Approve" }, :session => { :user_id => 1 }
    p1.reload
    assert_equal("active", p1.status)

    post :moderate, :params => { :ids => { p2.id => "1" }, :reason => "sage", :commit => "Delete" }, :session => { :user_id => 1 }
    p2.reload
    assert_equal("deleted", p2.status)
    assert_not_nil(p2.flag_detail)
    assert_equal("sage", p2.flag_detail.reason)
  end

  def test_update
    p1 = create_post("hoge", 1)

    post :update, :params => { :post => { :tags => "moge", :rating => "Explicit" }, :id => p1.id }, :session => { :user_id => 3 }
    p1.reload
    assert_equal("moge", p1.cached_tags)
    assert_equal("e", p1.rating)
  end

  test "update with empty params" do
    p1 = create_post("hoge", 1)

    post :update, :params => { :id => p1.id, :format => :json }, :session => { :user_id => 3 }

    assert_response :unprocessable_entity
  end

  def test_destroy
    p1 = create_post("hoge", 1, :user_id => 3)

    get :delete, :params => { :id => p1.id }, :session => { :user_id => 3 }
    assert_response :success

    post :destroy, :params => { :id => p1.id, :reason => "sage" }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "user", :action => "login"
    p1.reload
    assert_equal("active", p1.status)

    post :destroy, :params => { :id => p1.id, :reason => "sage" }, :session => { :user_id => 3 }
    p1.reload
    assert_equal("deleted", p1.status)
    assert_not_nil(p1.flag_detail)
    assert_equal("sage", p1.flag_detail.reason)
    p1.undelete

    post :destroy, :params => { :id => p1.id, :reason => "sage" }, :session => { :user_id => 1 }
    p1.reload
    assert_equal("deleted", p1.status)
    assert_not_nil(p1.flag_detail)
    assert_equal("sage", p1.flag_detail.reason)

    post :destroy, :params => { :id => p1.id, :reason => "sage", :destroy => 1 }, :session => { :user_id => 1 }
    assert_nil(Post.find_by_id(p1.id))
  end

  def test_deleted_index
    get :deleted_index, :session => { :user_id => 3 }
    assert_response :success

    get :deleted_index, :params => { :user_id => 1 }, :session => { :user_id => 3 }
    assert_response :success
  end

  def test_index
    create_default_posts

    get :index, :session => { :user_id => 3 }
    assert_response :success

    get :index, :params => { :tags => "tag1" }, :session => { :user_id => 3 }
    assert_response :success

    get :index, :params => { :format => "json" }, :session => { :user_id => 3 }
    assert_response :success

    get :index, :params => { :format => "xml" }, :session => { :user_id => 3 }
    assert_response :success
  end

  def test_atom
    create_default_posts

    get :atom, :params => { :format => :atom }, :session => { :user_id => 3 }
    assert_response :success

    get :atom, :params => { :format => :atom, :tags => "tag1" }, :session => { :user_id => 3 }
    assert_response :success
  end

  def test_piclens
    create_default_posts

    get :piclens, :params => { :format => :rss }, :session => { :user_id => 3 }
    assert_response :success

    get :piclens, :params => { :format => :rss, :tags => "tag1" }, :session => { :user_id => 3 }
    assert_response :success
  end

  def test_show
    get :show, :params => { :id => 1 }, :session => { :user_id => 3 }
    assert_response :success
  end

  def test_popular
    get :popular_by_day, :session => { :user_id => 3 }
    assert_response :success
  end

  def test_revert_tags
    p1 = create_post("tag1", 1)
    update_post(p1, :tags => "hoge")
    update_post(p1, :tags => "moge")

    history_id = p1.tag_history[-1].id

    post :revert_tags, :params => { :id => p1.id, :history_id => history_id }, :session => { :user_id => 3 }
    p1.reload
    assert_equal("tag1", p1.cached_tags)
  end

  def test_vote
    p1 = create_post("tag1", 1)

    post :vote, :params => { :id => p1.id, :score => 1 }, :session => { :user_id => 3 }
    p1.reload
    assert_equal(1, p1.score)

    p2 = create_post("tag2", 2)

    post :vote, :params => { :id => p2.id, :score => 5 }, :session => { :user_id => 3 }
    p2.reload
    assert_equal(0, p2.score)
  end

  def test_flag
    p1 = create_post("tag1", 1)

    post :flag, :params => { :id => p1.id, :reason => "sage" }, :session => { :user_id => 3 }

    p1.reload
    assert_equal("flagged", p1.status)
    assert_not_nil(p1.flag_detail)
    assert_equal("sage", p1.flag_detail.reason)
  end

  def test_random
    get :random, :session => { :user_id => 3 }
    assert_response :redirect
  end

  def test_undelete
    p1 = create_post("tag1", 1, :status => "deleted")

    post :undelete, :params => { :id => p1.id }, :session => { :user_id => 2 }

    p1.reload
    assert_equal("active", p1.status)
  end

  test "accessing #activate without parameter doesn't fail" do
    post :activate, :session => { :user_id => 2 }

    assert_response :success
  end
end
