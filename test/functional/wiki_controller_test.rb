require File.dirname(__FILE__) + '/../test_helper'

class WikiControllerTest < ActionController::TestCase
  fixtures :users
  
  def create_page(title, params = {})
    WikiPage.create({:title => title, :body => title, :user_id => 1, :ip_addr => "127.0.0.1", :is_locked => false}.merge(params))
  end
  
  def test_destroy
    page = create_page("hoge")

    post :destroy, {:title => "hoge"}, {:user_id => 2}    
    assert_nil(WikiPage.find_by_id(page.id))
  end
  
  def test_lock
    page = create_page("hoge")
    
    post :lock, {:title => "hoge"}, {:user_id => 2}
    page.reload
    assert_equal(true, page.is_locked?)
    
    post :unlock, {:title => "hoge"}, {:user_id => 2}
    page.reload
    assert_equal(false, page.is_locked?)
  end
  
  def test_index
    page1 = create_page("hoge")
    page2 = create_page("moge")
    
    get :index
    assert_response :success
    
    get :index, {:query => "moge"}
    assert_response :success
  end
  
  def test_preview
    get :preview, {:body => "hoge moge soge"}
    assert_response :success
  end
  
  def test_create
    get :add, {:title => "moge"}, {:user_id => 4}
    assert_response :success

    post :create, {:wiki_page => {:title => "hoge", :body => "hoge hoge"}}, {:user_id => 4}
    page = WikiPage.find_by_title("hoge")
    assert_not_nil(page)
    assert_equal("hoge hoge", page.body)
  end
  
  def test_update
    page = create_page("hoge")
    page.update_attributes(:body => "moge moge")
    
    get :edit, {:title => "hoge"}, {:user_id => 4}
    assert_response :success
    
    get :edit, {:title => "hoge", :version => 1}, {:user_id => 4}
    assert_response :success
    
    post :update, {:wiki_page => {:title => "hoge", :body => "soge king"}}, {:user_id => 4}
    page.reload
    assert_equal("soge king", page.body)
  end
  
  def test_show
    page = create_page("hoge")
    page.update_attributes(:body => "moge moge")
    
    get :show, {:title => "hoge"}
    assert_response :success
  end
  
  def test_revert_unlocked
    page = create_page("hoge")
    page.update_attributes(:body => "hoge 2")
    page.update_attributes(:body => "hoge 3")
    
    post :revert, {:title => "hoge", :version => 1}, {:user_id => 4}
    page.reload
    assert_equal("hoge", page.body)
  end

  def test_revert_locked
    page = create_page("hoge", :is_locked => true)
    page.update_attributes(:body => "hoge hoge")
    page.update_attributes(:body => "hoge hoge hoge")
    
    post :revert, {:title => "hoge", :version => 2}, {:user_id => 4}
    page.reload
    assert_equal("hoge hoge hoge", page.body)
  end
  
  def test_recent_changes
    page1 = create_page("hoge")
    page2 = create_page("moge")
    page2.update_attributes(:body => "moge moge")
    page2.update_attributes(:body => "moge moge moge")
    
    get :recent_changes
    assert_response :success
  end
  
  def test_history
    page = create_page("moge")
    page.update_attributes(:body => "moge moge")
    page.update_attributes(:body => "moge moge moge")
    
    get :history, {:title => "moge"}
    assert_response :success
  end
  
  def test_diff
    page = create_page("moge")
    page.update_attributes(:body => "moge moge")
    page.update_attributes(:body => "moge moge moge")
    
    get :diff, {:title => "moge", :from => 1, :to => 3}
    assert_response :success
  end
  
  def test_rename
    page = create_page("moge")
    
    get :rename, {:title => "moge"}, {:user_id => 2}
    assert_response :success
  end
end
