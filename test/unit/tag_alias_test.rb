require File.dirname(__FILE__) + '/../test_helper'

class TagAliasTest < ActiveSupport::TestCase
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
    
    @alias = TagAlias.create(:name => "tag2", :alias => "tag1", :is_pending => false, :reason => "none", :creator_id => 1)
    @test_number = 1
  end
  
  def create_tag(params = {})
    Tag.create({:post_count => 0, :cached_related => "", :cached_related_expires_on => Time.now, :tag_type => 0, :is_ambiguous => false}.merge(params))
  end
  
  def create_post(tags, params = {})
    post = Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{@test_number}.jpg")}.merge(params))
    @test_number += 1
    post
  end
  
  def test_to_aliased
    assert_equal(["tag1"], TagAlias.to_aliased(["tag2"]))
    assert_equal(["tag3"], TagAlias.to_aliased(["tag3"]))
  end
  
  def test_destroy_and_notify
    @alias.destroy_and_notify(User.find(2), "hohoho")
    assert_not_nil(Dmail.find_by_body("A tag alias you submitted (tag2 &rarr; tag1) was deleted for the following reason: hohoho."))
    assert_nil(TagAlias.find_by_id(@alias.id))
  end
  
  def test_normalize
    hoge = TagAlias.create(:name => "-ho ge", :alias => "tag3", :is_pending => false, :reason => "none", :creator_id => 1)
    assert_equal("ho_ge", hoge.name)
  end
  
  def test_uniqueness
    # Try to prevent cycles from being formed
    hoge = TagAlias.create(:name => "tag1", :alias => "tag3", :is_pending => false, :reason => "none", :creator_id => 1)
    assert_equal(["tag1 is already aliased to something"], hoge.errors.full_messages)

    hoge = TagAlias.create(:name => "tag2", :alias => "tag3", :is_pending => false, :reason => "none", :creator_id => 1)
    assert_equal(["tag2 is already aliased to something"], hoge.errors.full_messages)
  end
  
  def test_approve
    p1 = create_post("tag5 tag6 tag7")
    p2 = create_post("tag5")
    p3 = create_post("tag8")
    
    ta = TagAlias.create(:name => "tag5", :alias => "tagx", :is_pending => true, :reason => "none", :creator_id => 1)
    p1.reload
    p2.reload
    p3.reload
    assert_equal("tag5 tag6 tag7", p1.cached_tags)
    assert_equal("tag5", p2.cached_tags)
    assert_equal("tag8", p3.cached_tags)
    ta.approve(1, '127.0.0.1')
    p1.reload
    p2.reload
    p3.reload
    ta.reload
    assert(!ta.is_pending?, "Tag alias should have been marked as not pending")
    assert_equal("tag6 tag7 tagx", p1.cached_tags)
    assert_equal("tagx", p2.cached_tags)
    assert_equal("tag8", p3.cached_tags)
  end
  
  def test_api
    assert_nothing_raised {@alias.to_json}
    assert_nothing_raised {@alias.to_xml}
  end
end
