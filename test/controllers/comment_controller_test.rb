require "test_helper"

class CommentControllerTest < ActionController::TestCase
  fixtures :users, :posts

  def setup
    @post_number = 1
  end

  def create_comment(post_id, body, params = {})
    Comment.create({ :post_id => post_id, :user_id => 2, :body => body, :ip_addr => "127.0.0.1", :is_spam => false }.merge(params))
  end

  def test_update
    comment = create_comment(1, "hi there")

    get :edit, :params => { :id => comment.id }
    assert_response :success

    post :update, :params => { :id => comment.id, :comment => { :body => "muggle" } }, :session => { :user_id => 1 }
    assert_redirected_to :controller => "comment", :action => "index"
    comment.reload
    assert_equal("muggle", comment.body)

    # TODO: test privileges
  end

  def test_destroy
    comment = create_comment(1, "hi there")

    post :destroy, :params => { :id => comment.id }, :session => { :user_id => 1 }
    assert_redirected_to :controller => "post", :action => "show", :id => 1
    assert_nil(Comment.find_by_id(comment.id))

    # TODO: Test privileges
  end

  def test_create_simple
    post :create, :params => { :comment => { :post_id => 1, :body => "hoge" } }, :session => { :user_id => 1 }
    post = Post.find(1)
    assert_equal(1, post.comments.size)
    assert_equal("hoge", post.comments[0].body)
    assert_equal(1, post.comments[0].user_id)
    assert_not_nil(post.last_commented_at)
  end

  def test_create_throttling
    old_member_comment_limit = CONFIG["member_comment_limit"]
    CONFIG["member_comment_limit"] = 1
    create_comment(1, "c1", :user_id => 4)
    post :create, :params => { :comment => { :post_id => 1, :body => "c2" }, :commit => "Post" }, :session => { :user_id => 4 }
    assert_redirected_to :controller => "comment", :action => "index"
    assert_equal(1, Post.find(1).comments.size)
    assert_equal("c1", Post.find(1).comments[0].body)
    CONFIG["member_comment_limit"] = old_member_comment_limit
  end

  def test_create_do_not_bump_post
    # FIXME: this functionality has been disabled since forever.
    # post :create, { :comment => { :post_id => 1, :body => "hoge" }, :commit => "Post without bumping" }, :user_id => 1
    # post = Post.find(1)
    # binding.pry
    # assert_equal(1, post.comments.size)
    # assert_nil(post.last_commented_at)
  end

  def test_show
    comment = create_comment(1, "hoge")
    get :show, :params => { :id => comment.id }, :session => { :user_id => 4 }
    assert_response :success
  end

  def test_index
    create_comment(1, "hoge")
    create_comment(1, "moogle")
    create_comment(3, "box")
    create_comment(2, "tree")
    get :index, :session => { :user_id => 4 }
    assert_response :success
  end

  def test_mark_as_spam
    # TODO: allow janitors to mark spam
    comment = create_comment(1, "hoge")
    post :mark_as_spam, :params => { :id => comment.id }, :session => { :user_id => 2 }
    comment.reload
    assert(comment.is_spam?, "Comment not marked as spam")
  end

  def test_moderate
    create_comment(1, "hoge")
    create_comment(1, "moogle")
    create_comment(3, "box")
    create_comment(2, "tree")
    get :moderate, :session => { :user_id => 2 }
    assert_response :success
  end
end
