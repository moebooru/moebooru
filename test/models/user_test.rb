require "test_helper"

class UserTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @post_number = 1
  end

  def create_user(name, params = {})
    user = User.new({ :password => "zugzug1", :password_confirmation => "zugzug1", :email => "a@b.net" }.merge(params))
    user.name = name
    user.level = CONFIG["user_levels"]["Member"]
    user.save
    user
  end

  def create_post(tags, user_id = 1, params = {})
    post = Post.create({ :user_id => user_id, :score => 0, :source => "", :rating => "s", :width => 100, :height => 100, :ip_addr => "127.0.0.1", :updater_ip_addr => "127.0.0.1", :updater_user_id => 1, :tags => tags, :status => "active", :file => upload_file("#{Rails.root}/test/mocks/test/test#{@post_number}.jpg") }.merge(params))
    @post_number += 1
    post
  end

  def create_favorite(user_id, post_id)
    PostVote.create(:user_id => user_id, :post_id => post_id, :score => 3)
  end

  def test_blacklists
    CONFIG["default_blacklists"] = ["tag1"]
    user = create_user("bob")
    user.password = user.password_confirmation = nil # to skip password validation check
    assert_equal("tag1\n", user.blacklisted_tags)

    user.update(:blacklisted_tags => "tag2\ntag3\n")
    assert_equal("tag2\ntag3\n", user.blacklisted_tags)
  end

  def test_authentication
    user = create_user("bob")
    assert(User.authenticate("bob", "zugzug1"), "Authentication should have succeeded")
    assert(!User.authenticate("bob", "zugzug2"), "Authentication should not have succeeded")
    assert(User.authenticate_hash("bob", user.password_hash), "Authentication should have succeeded")
    assert(!User.authenticate_hash("bob", "xxxx"), "Authentication should not have succeeded")
  end

  def test_passwords
    user = create_user("bob")
    user.current_password = "zugzug1"
    user.password = "zugzug5"
    user.password_confirmation = "zugzug5"
    user.save
    user.reload
    assert(User.authenticate("bob", "zugzug5"), "Authentication should have succeeded")

    user.current_password = "zugzug5"
    user.password = "zugzug6"
    user.password_confirmation = "zugzug5"
    user.save
    assert_equal(["Password confirmation doesn't match Password"], user.errors.full_messages)

    user.password = "x5"
    user.password_confirmation = "x5"
    user.save
    assert_equal(["Password is too short (minimum is 5 characters)"], user.errors.full_messages)

    new_pass = user.reset_password
    assert(User.authenticate("bob", new_pass), "Authentication should have succeeded")
  end

  def test_find_name
    user = create_user("bob")
    assert_equal(CONFIG["default_guest_name"], User.find_name(-1))
    assert_equal("bob", User.find_name(user.id))
    user.name = "max"
    user.password = user.password_confirmation = nil # to skip password check
    user.save
    assert_equal("max", User.find_name(user.id))
  end

  def test_api
    user = create_user("bob")
    assert_nothing_raised { user.to_json }
    assert_nothing_raised { user.to_xml }
  end

  def test_uploaded_tags
    create_post("tag1")
    create_post("tag1")
    create_post("tag2")
    create_post("tag1", 2)
    results = User.find(1).uploaded_tags.sort { |a, b| a["tag"] <=> b["tag"] }
    assert_equal(2, results.size)
    assert_equal("tag1", results[0]["tag"])
    assert_equal(2, results[0]["count"])
    assert_equal("tag2", results[1]["tag"])
    assert_equal(1, results[1]["count"])
  end

  def test_uploaded_posts
    p1 = create_post("tag1", 2)
    p2 = create_post("tag2", 2)
    p3 = create_post("tag3", 2)
    create_post("tag4", 3)
    results = User.find(2).recent_uploaded_posts.map(&:id).sort
    assert_equal([p1.id, p2.id, p3.id], results)
  end

  def test_favorite_posts
    p1 = create_post("tag1")
    p2 = create_post("tag2")
    create_post("tag3")
    create_post("tag4")
    create_favorite(2, p1.id)
    create_favorite(2, p2.id)
    results = User.find(2).recent_favorite_posts.map(&:id).sort
    assert_equal([p1.id, p2.id], results)
  end

  #  def test_favorites
  #    p1 = create_post("tag1")
  #    p2 = create_post("tag2")
  #    p3 = create_post("tag3")
  #    p4 = create_post("tag4")
  #    user = User.find(1)
  #    create_favorite(user.id, p1.id)
  #    assert_not_nil(Favorite.find(:first, :conditions => ["user_id = 1 AND post_id = ?", p1.id]))
  #    assert_raise(User::AlreadyFavoritedError) {user.add_favorite(p1.id)}
  #    assert_equal(1, Favorite.count(:conditions => ["user_id = 1 AND post_id = ?", p1.id]))
  #    user.delete_favorite(p1.id)
  #    assert_nil(Favorite.find(:first, :conditions => ["user_id = 1 AND post_id = ?", p1.id]))
  #    assert_nothing_raised {user.delete_favorite(p1.id)}
  #  end

  def test_levels
    admin = User.find(1)
    mod = User.find(2)
    priv = User.find(3)
    member = User.find(4)
    assert_equal("Admin", admin.pretty_level)

    p1 = create_post("tag1", 4)
    assert(admin.has_permission?(p1), "Admin should have permission")
    assert(mod.has_permission?(p1), "Mod should have permission")
    assert(!priv.has_permission?(p1), "Non-mod should not have permission")
    assert(member.has_permission?(p1), "Owner should have permission")

    assert(mod.is_mod_or_higher?)
    assert(mod.is_blocked_or_higher?)
    assert(!mod.is_blocked_or_lower?)
    assert(!mod.is_member?)
    assert(mod.is_mod?)
  end
end
