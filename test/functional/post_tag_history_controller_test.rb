require File.dirname(__FILE__) + '/../test_helper'

class PostTagHistoryControllerTest < ActionController::TestCase
  fixtures :users
  
  def create_post(tags, post_number = 1, params = {})
    Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{post_number}.jpg")}.merge(params))
  end
  
  def update_post(post, params = {})
    post.update_attributes({:updater_user_id => 1, :updater_ip_addr => '127.0.0.1'}.merge(params))
  end
  
  def test_index
    p1 = create_post("tag1")
    update_post(p1, :tags => "moge")
    update_post(p1, :tags => "hoge")
    
    get :index, {}, {:user_id => 3}
    assert_response :success
  end
  
  def test_revert
    p1 = create_post("tag1")
    update_post(p1, :tags => "moge")
    update_post(p1, :tags => "hoge")
    
    post :revert, {:id => p1.tag_history[-1].id, :commit => "Yes"}, {:user_id => 3}
    p1.reload
    assert_equal("tag1", p1.cached_tags)
  end
  
  def test_undo
    p1 = create_post("a")
    update_post(p1, :tags => "a b")

    post :undo, {:id => p1.tag_history[0].id}, {:user_id => 3}
    p1.reload
    assert_equal("a", p1.cached_tags)
  end
end
