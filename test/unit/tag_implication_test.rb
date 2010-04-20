require File.dirname(__FILE__) + '/../test_helper'

class TagImplicationTest < ActiveSupport::TestCase
  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
    
    @test_number = 1
    @impl = TagImplication.create(:predicate => "taga", :consequent => "tagb", :creator_id => 1, :is_pending => false)
  end
  
  def create_post(tags, params = {})
    post = Post.create({:user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => '127.0.0.1', :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_jpeg("#{RAILS_ROOT}/test/mocks/test/test#{@test_number}.jpg")}.merge(params))
    @test_number += 1
    post
  end

  def test_api
    assert_nothing_raised {@impl.to_json}
    assert_nothing_raised {@impl.to_xml}
  end
  
  def test_uniqueness
    hoge = TagImplication.create(:predicate => "tagb", :consequent => "tagc", :is_pending => false)
    assert(hoge.errors.empty?, "Tag implication should not have any errors")
    
    hoge = TagImplication.create(:predicate => "taga", :consequent => "tagc", :is_pending => false)
    assert(hoge.errors.empty?, "Tag implication should not have any errors")

    hoge = TagImplication.create(:predicate => "tagb", :consequent => "taga", :is_pending => false)
    assert_equal(["Tag implication already exists"], hoge.errors.full_messages)
    
    hoge = TagImplication.create(:predicate => "taga", :consequent => "tagb", :is_pending => false)
    assert_equal(["Tag implication already exists"], hoge.errors.full_messages)
  end
  
  def test_approve
    p1 = create_post("tag1 tag2 tag3")
    p2 = create_post("tag1 tag4")
    p3 = create_post("tag5 tag6")
    impl = TagImplication.create(:predicate => "tag1", :consequent => "tagz", :is_pending => false)
    p1.reload
    p2.reload
    p3.reload
    assert_equal("tag1 tag2 tag3", p1.cached_tags)
    assert_equal("tag1 tag4", p2.cached_tags)
    assert_equal("tag5 tag6", p3.cached_tags)
    impl.approve(1, "127.0.0.1")
    impl.reload
    assert(!impl.is_pending?, "Tag implication should no longer be pending")
    p1.reload
    p2.reload
    p3.reload
    assert_equal("tag1 tag2 tag3 tagz", p1.cached_tags)
    assert_equal("tag1 tag4 tagz", p2.cached_tags)
    assert_equal("tag5 tag6", p3.cached_tags)
  end
  
  def test_with_implied
    TagImplication.create(:predicate => "tag1", :consequent => "tagz", :is_pending => false)
    TagImplication.create(:predicate => "tag1", :consequent => "tagx", :is_pending => false)
    TagImplication.create(:predicate => "tagx", :consequent => "tag9", :is_pending => false)
    assert_equal(["tag1", "tag9", "tagx", "tagz"], TagImplication.with_implied(["tag1"]).sort)
  end
  
  def test_destroy_and_notify
    @impl.destroy_and_notify(User.find(2), "hohoho")
    assert_not_nil(Dmail.find_by_body("A tag implication you submitted (taga &rarr; tagb) was deleted for the following reason: hohoho."))
    assert_nil(TagImplication.find_by_id(@impl.id))
  end
end
