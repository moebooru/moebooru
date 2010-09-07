require File.dirname(__FILE__) + '/../test_helper'

class TagSubscriptionTest < ActiveSupport::TestCase
  fixtures :users
  
  def setup
    @test_number = 1
  end
  
  def create_post(tags, params = {})
    post = Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{@test_number}.jpg")}.merge(params))
    @test_number += 1
    post
  end
  
  def create_tag_subscription(tags, params = {})
    TagSubscription.create({:tag_query => tags, :name => "General", :user_id => 1}.merge(params))
  end
  
  def test_initial_posts
    p1 = create_post("tag1 tag2 tag3")
    p2 = create_post("tag2")
    p3 = create_post("tag3")
    p4 = create_post("tag4")
    
    ft = create_tag_subscription("tag2")
    assert_equal("#{p2.id},#{p1.id}", ft.cached_post_ids)
  end
  
  def test_prune
    old = CONFIG["tag_subscription_post_limit"]
    CONFIG["tag_subscription_post_limit"] = 3

    ft = create_tag_subscription("tag1")
    ft.update_attribute(:cached_post_ids, "6,5,4,3,2,1")
    ft.prune!
    assert_equal("6", ft.cached_post_ids)
    
    CONFIG["tag_subscription_post_limit"] = old
  end
  
  def test_find_post_ids
    p1 = create_post("tag1 tag2 tag3")
    p2 = create_post("tag2")
    p3 = create_post("tag3")
    p4 = create_post("tag4")

    ft1 = create_tag_subscription("tag2")
    ft2 = create_tag_subscription("tag3", :name => "Special")

    assert_equal([p3.id, p2.id, p1.id], TagSubscription.find_post_ids(1).sort.reverse.map {|x| x.to_i})
    assert_equal([p3.id, p1.id], TagSubscription.find_post_ids(1, "Special").sort.reverse.map {|x| x.to_i})
    assert_equal([p3.id], TagSubscription.find_post_ids(1, nil, 1).map {|x| x.to_i})
  end
  
  def test_process_all
    ft = create_tag_subscription("tag2")
    p1 = create_post("tag1 tag2 tag3")
    p2 = create_post("tag2")
    p3 = create_post("tag3")
    p4 = create_post("tag4")
    TagSubscription.process_all
    ft.reload
    assert_equal("#{p2.id},#{p1.id}", ft.cached_post_ids)
  end
end
