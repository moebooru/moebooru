require File.dirname(__FILE__) + '/../test_helper'

class FavoriteControllerTest < ActionController::TestCase
  fixtures :users, :posts

  def test_all
    post :create, {:id => 1}, {:user_id => 1}
    p = Post.find(1)
    assert_equal(1, p.score)
    assert_equal(1, p.fav_count)
    assert_not_nil(Favorite.find(:first, :conditions => ["post_id = 1 AND user_id = 1"]))
    
    post :destroy, {:id => 1}, {:user_id => 1}
    p.reload
    assert_equal(0, p.score)
    assert_equal(0, p.fav_count)
    assert_nil(Favorite.find(:first, :conditions => ["post_id = 1 AND user_id = 1"]))
  end
end
