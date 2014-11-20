require File.dirname(__FILE__) + "/../test_helper"

class CommentTest < ActiveSupport::TestCase
  fixtures :users, :posts

  def setup
    if CONFIG["enable_caching"]
      Rails.cache.clear
    end
  end

  def test_simple
    comment = Comment.create(:post_id => 1, :user_id => 1, :body => "hello world", :ip_addr => "127.0.0.1")
    assert_equal("admin", comment.author)
    assert_equal("hello world", comment.body)
    assert_equal(comment.created_at, Post.find(1).last_commented_at)
  end

  #  def test_no_bump
  #    comment = Comment.create(:do_not_bump_post => "1", :post_id => 1, :user_id => 1, :body => "hello world", :ip_addr => "127.0.0.1")
  #    assert_equal("admin", comment.author)
  #    assert_equal("hello world", comment.body)
  #    assert_nil(Post.find(1).last_commented_at)
  #  end

  def test_threshold
    old_threshold = CONFIG["comment_threshold"]
    CONFIG["comment_threshold"] = 1

    comment_a = Comment.create(:post_id => 1, :user_id => 1, :body => "mark 1", :ip_addr => "127.0.0.1")
    sleep 1
    Comment.create(:post_id => 1, :user_id => 1, :body => "mark 2", :ip_addr => "127.0.0.1")
    assert_equal(comment_a.created_at.to_s, Post.find(1).last_commented_at.to_s)

    CONFIG["comment_threshold"] = old_threshold
  end

  def test_api
    comment = Comment.create(:post_id => 1, :user_id => 1, :body => "hello world", :ip_addr => "127.0.0.1")
    assert_nothing_raised do
      comment.to_xml
    end
    assert_nothing_raised do
      comment.to_json
    end
  end
end
