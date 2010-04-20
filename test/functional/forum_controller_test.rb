require File.dirname(__FILE__) + '/../test_helper'

class ForumControllerTest < ActionController::TestCase
  fixtures :users

  def create_post(msg, parent_id = nil, params = {})
    ForumPost.create({:creator_id => 1, :body => msg, :title => msg, :is_sticky => false, :parent_id => parent_id, :is_locked => false}.merge(params))
  end

  def test_stick
    p = create_post("parent")

    post :stick, {:id => p.id}, {:user_id => 2}
    p.reload
    assert(p.is_sticky?, "Post should be sticky")
    
    post :unstick, {:id => p.id}, {:user_id => 2}
    p.reload
    assert(!p.is_sticky?, "Post should not be sticky")
  end
  
  def test_lock
    p = create_post("parent")
    
    post :lock, {:id => p.id}, {:user_id => 2}
    p.reload
    assert(p.is_locked?, "Post should be locked")
    
    post :unlock, {:id => p.id}, {:user_id => 2}
    p.reload
    assert(!p.is_locked?, "Post should not be locked")
  end
  
  def test_create
    post :create, {:forum_post => {:title => "hey", :body => "hey"}}, {:user_id => 4}
    p1 = ForumPost.find_by_title("hey")
    assert_not_nil(p1)
    assert_nil(p1.parent_id)
    assert_equal(4, p1.creator_id)
    assert_equal(4, p1.last_updated_by)
    assert_equal(0, p1.response_count)

    post :create, {:forum_post => {:title => "hoge", :body => "hoge", :parent_id => p1.id}}, {:user_id => 3}
    p1.reload
    p2 = ForumPost.find_by_title("hoge")
    assert_not_nil(p2)
    assert_equal(3, p2.creator_id)
    assert_equal(p1.id, p2.parent_id)
    assert_equal(3, p1.last_updated_by)
    assert_equal(p2.created_at.to_i, p1.updated_at.to_i)
  end
  
  def test_destroy
    p1 = create_post("hello")
    p2 = create_post("go away", p1.id)
    
    post :destroy, {:id => p1.id}, {:user_id => 1}
    assert_nil(ForumPost.find_by_id(p1.id))
    assert_nil(ForumPost.find_by_id(p2.id))
  end
  
  def test_update
    p1 = create_post("hello")
    
    get :edit, {:id => p1.id}, {:user_id => 1}
    assert_response :success
    
    post :update, {:id => p1.id, :forum_post => {:body => "taxes"}}, {:user_id => 1}
    p1.reload
    assert_equal("taxes", p1.body)
  end
  
  def test_show
    p1 = create_post("hello")
    get :show, {:id => p1.id}, {:user_id => 1}
    assert_response :success
  end
  
  def test_index
    p1 = create_post("hello")
    p2 = create_post("hello", p1.id)
    p3 = create_post("hello", p1.id)
    p4 = create_post("hello")
    p5 = create_post("hello", p4.id)
    p6 = create_post("hello", p4.id)
    p7 = create_post("hello", p4.id)
    
    get :index, {}, {:user_id => 1}
    assert_response :success
    
    get :index, {:parent_id => p4.id}, {:user_id => 1}
    assert_response :success
  end
  
  def test_search
    p1 = create_post("hello")
    p2 = create_post("margery", p1.id)
    p3 = create_post("daw", p1.id)
    p4 = create_post("existential")
    p5 = create_post("pie", p4.id)
    p6 = create_post("moon", p4.id)
    p7 = create_post("knife", p4.id)
    
    get :search, {}, {:user_id => 1}
    assert_response :success
    
    get :search, {:query => "hello"}, {:user_id => 1}
    assert_response :success
  end
  
  def test_mark_all_read
    p1 = create_post("hello")
    p2 = create_post("margery", p1.id)
    p3 = create_post("daw", p1.id)
    p4 = create_post("existential")
    p5 = create_post("pie", p4.id)
    p6 = create_post("moon", p4.id)
    p7 = create_post("knife", p4.id)

    post :mark_all_read, {}, {:user_id => 1}
    assert_response :success
  end
end
