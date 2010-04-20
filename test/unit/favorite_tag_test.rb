require File.dirname(__FILE__) + '/../test_helper'

class FavoriteTagTest < ActiveSupport::TestCase
  fixtures :users
  
  def create_fav_tag(tag_query, user_id)
    FavoriteTag.create(:tag_query => tag_query, :user_id => user_id, :cached_post_ids => "")
  end
  
  def create_post(post_number, params = {})
    Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :status => "active", :tags => "tag1 tag2", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{post_number}.jpg")}.merge(params))
  end
  
  def test_interested
    p1 = create_post(1, :tags => "hoge")
    p2 = create_post(2, :tags => "moge")
    fav_tag = create_fav_tag("hoge", 1)
        
    assert(fav_tag.interested?(p1.id))
    assert(!fav_tag.interested?(p2.id))
  end
  
  def test_add_post
    p1 = create_post(1, :tags => "hoge")
    p2 = create_post(2, :tags => "moge")
    fav_tag = create_fav_tag("hoge", 1)
    
    p3 = create_post(3, :tags => "hoge moge")
    FavoriteTag.process_all(p2.id)
    fav_tag.reload
    
    assert_equal("#{p3.id},#{p1.id}", fav_tag.cached_post_ids)
  end
  
  def test_prune
    old_limit = CONFIG["favorite_tag_limit"]
    
    CONFIG["favorite_tag_limit"] = 1
    
    p1 = create_post(1, :tags => "hoge")
    p2 = create_post(2, :tags => "moge")
    fav_tag = create_fav_tag("hoge", 1)
    
    fav_tag.add_post!(p1.id)
    fav_tag.add_post!(p2.id)
    fav_tag.prune!
    assert_equal("#{p2.id}", fav_tag.cached_post_ids)

    CONFIG["favorite_tag_limit"] = old_limit
  end
  
  def test_find_posts
    p1 = create_post(1, :tags => "hoge")
    p2 = create_post(2, :tags => "moge")
    fav_tag = create_fav_tag("hoge", 1)
    fav_tag.add_post!(p1.id)
    fav_tag.add_post!(p2.id)
    
    assert_equal([p1.id, p2.id], FavoriteTag.find_posts(1).map(&:id).sort)
    
    fav_tag_2 = create_fav_tag("soge", 1)
    p3 = create_post(3, :tags => "soge")
    fav_tag_2.add_post!(p3.id)
    
    assert_equal([p1.id, p2.id, p3.id], FavoriteTag.find_posts(1).map(&:id).sort)
  end
  
  def test_process_all
    fav_tag = create_fav_tag("hoge", 1)
    
    p1 = create_post(1, :tags => "hoge")
    p2 = create_post(2, :tags => "moge")
    
    FavoriteTag.process_all(0)
    
    fav_tag.reload
    assert_equal("#{p1.id}", fav_tag.cached_post_ids)
  end
end
