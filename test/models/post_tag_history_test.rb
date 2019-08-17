require "test_helper"

class PostTagHistoryTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @test_number = 1
  end

  def create_post(params = {})
    p = Post.create({ :user_id => 1, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => "127.0.0.1", :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :status => "active", :tags => "tag1", :file => upload_file("#{Rails.root}/test/mocks/test/test#{@test_number}.jpg") }.merge(params))
    @test_number += 1
    p
  end

  def update_post(post, params = {})
    post.update({ :updater_user_id => 1, :updater_ip_addr => "127.0.0.1" }.merge(params))
  end

  def test_simple
    p1 = create_post
    update_post(p1, :tags => "tag2")
    update_post(p1, :tags => "tag3")
    p1.reload
    assert_equal(3, p1.tag_history.size)
    assert_equal("rating:s tag3", p1.tag_history[0].tags)
    assert_equal("rating:s tag2", p1.tag_history[1].tags)
    assert_equal("rating:s tag1", p1.tag_history[2].tags)
  end

  def test_rating
    p1 = create_post
    update_post(p1, :rating => "e", :tags => "tag1")
    update_post(p1, :rating => "q", :tags => "tag2")
    p1.reload
    assert_equal(3, p1.tag_history.size)
    assert_includes(p1.tag_history[0].tags.split, "rating:q")
    assert_includes(p1.tag_history[1].tags.split, "rating:e")
    assert_includes(p1.tag_history[2].tags.split, "rating:s")
  end

  def test_api
    p1 = create_post
    assert_nothing_raised { p1.tag_history[0].to_json }
    assert_nothing_raised { p1.tag_history[0].to_xml }
  end

  def test_undo
    p1 = create_post(:tags => "a")
    update_post(p1, :tags => "a b")

    options = { :update_options => { :updater_ip_addr => "127.0.0.1", :updater_user_id => 3 } }
    p1.tag_history[0].undo(options)
    options[:posts].each_value(&:save)
    p1.reload
    assert_equal("a", p1.cached_tags)
  end

  def test_changes_after_adding_tags
    p1 = create_post
    update_post(p1, :tags => "tag1 tag2")
    p1.reload
    assert_equal(["tag2"], p1.tag_history[0].tag_changes(p1.tag_history[1])[:added_tags])
    assert_equal([], p1.tag_history[0].tag_changes(p1.tag_history[1])[:removed_tags])
    assert_equal(["rating:s", "tag1"], p1.tag_history[0].tag_changes(p1.tag_history[1])[:unchanged_tags])
  end

  def test_changes_after_removing_tags
    p1 = create_post
    update_post(p1, :tags => "tag2")
    p1.reload
    assert_equal(["tag2"], p1.tag_history[0].tag_changes(p1.tag_history[1])[:added_tags])
    assert_equal(["tag1"], p1.tag_history[0].tag_changes(p1.tag_history[1])[:removed_tags])
    assert_equal(["rating:s"], p1.tag_history[0].tag_changes(p1.tag_history[1])[:unchanged_tags])
  end
end
