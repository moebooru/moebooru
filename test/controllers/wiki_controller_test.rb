require "test_helper"

class WikiControllerTest < ActionController::TestCase
  fixtures :users

  def create_page(title, params = {})
    WikiPage.create({ :title => title, :body => title, :user_id => 1, :ip_addr => "127.0.0.1", :is_locked => false }.merge(params))
  end

  def test_destroy
    page = create_page("hoge")

    post :destroy, :params => { :title => "hoge" }, :session => { :user_id => 2 }
    assert_nil(WikiPage.find_by_id(page.id))
  end

  def test_lock
    page = create_page("hoge")

    post :lock, :params => { :title => "hoge" }, :session => { :user_id => 2 }
    page.reload
    assert_equal(true, page.is_locked?)

    post :unlock, :params => { :title => "hoge" }, :session => { :user_id => 2 }
    page.reload
    assert_equal(false, page.is_locked?)
  end

  def test_index
    create_page("hoge")
    create_page("moge")

    get :index
    assert_response :success

    get :index, :params => { :query => "moge" }
    assert_response :success
  end

  def test_preview
    get :preview, :params => { :body => "hoge moge soge" }
    assert_response :success
  end

  def test_create
    get :add, :params => { :title => "moge" }, :session => { :user_id => 4 }
    assert_response :success

    post :create, :params => { :wiki_page => { :title => "hoge", :body => "hoge hoge" } }, :session => { :user_id => 4 }
    page = WikiPage.find_by_title("hoge")
    assert_not_nil(page)
    assert_equal("hoge hoge", page.body)
  end

  def test_update
    page = create_page("hoge")
    page.update(:body => "moge moge")

    get :edit, :params => { :title => "hoge" }, :session => { :user_id => 4 }
    assert_response :success

    get :edit, :params => { :title => "hoge", :version => 1 }, :session => { :user_id => 4 }
    assert_response :success

    post :update, :params => { :wiki_page => { :title => "hoge", :body => "soge king" } }, :session => { :user_id => 4 }
    page.reload
    assert_equal("soge king", page.body)
  end

  def test_show
    page = create_page("hoge")
    page.update(:body => "moge moge")

    get :show, :params => { :title => "hoge" }
    assert_response :success
  end

  def test_revert_unlocked
    page = create_page("hoge")
    page.update(:body => "hoge 2")
    page.update(:body => "hoge 3")

    post :revert, :params => { :title => "hoge", :version => 1 }, :session => { :user_id => 4 }
    page.reload
    assert_equal("hoge", page.body)
  end

  def test_revert_locked
    page = create_page("hoge", :is_locked => true)
    page.update(:body => "hoge hoge")
    page.update(:body => "hoge hoge hoge")

    post :revert, :params => { :title => "hoge", :version => 2 }, :session => { :user_id => 4 }
    page.reload
    assert_equal("hoge hoge hoge", page.body)
  end

  def test_recent_changes
    create_page("hoge")
    page2 = create_page("moge")
    page2.update(:body => "moge moge")
    page2.update(:body => "moge moge moge")

    get :recent_changes
    assert_response :success
  end

  def test_history
    page = create_page("moge")
    page.update(:body => "moge moge")
    page.update(:body => "moge moge moge")

    get :history, :params => { :title => "moge" }
    assert_response :success
  end

  def test_diff
    page = create_page("moge")
    page.update(:body => "moge moge")
    page.update(:body => "moge moge moge")

    get :diff, :params => { :title => "moge", :from => 1, :to => 3 }
    assert_response :success
  end

  def test_rename
    create_page("moge")

    get :rename, :params => { :title => "moge" }, :session => { :user_id => 2 }
    assert_response :success
  end
end
