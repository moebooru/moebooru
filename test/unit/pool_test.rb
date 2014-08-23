require File.dirname(__FILE__) + "/../test_helper"

class PoolTest < ActiveSupport::TestCase
  fixtures :users, :posts

  def setup
    if CONFIG["enable_caching"]
      CACHE.flush_all
    end
  end

  def create_pool(params = {})
    Pool.create({:user_id => 1, :name => "my pool", :post_count => 0, :is_public => false, :description => "pools"}.merge(params))
  end

  def find_post(pool, post_id)
    PoolPost.find(:first, :conditions => ["pool_id = ? AND post_id = ?", pool.id, post_id])
  end

  def add_posts(pool, options = {})
    pool.add_post(1)
    pool.add_post(2)
    pool.add_post(3)
    pool.add_post(4)
  end

  def test_normalize
    pool = create_pool
    assert_equal("my_pool", pool.name)
  end

  def test_uniqueness
    pool1 = create_pool
    pool2 = create_pool
    assert_equal(1, Pool.count(["name = 'my_pool'"]))
  end

  def test_api
    pool = create_pool
    assert_nothing_raised do
      pool.to_json
    end

    assert_nothing_raised do
      pool.to_xml
    end
  end

  def test_remove_nonexistent_post
    pool = create_pool
    add_posts(pool)

    assert_nothing_raised do
      pool.remove_post(1000)
    end
  end

  def test_remove_post_from_head
    pool = create_pool
    add_posts(pool)

    pool.remove_post(1)
    assert_equal(3, pool.post_count)
    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    post3 = find_post(pool, 3)
    post4 = find_post(pool, 4)
    assert(!post1.active)
    assert_nil(post2.prev_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_equal(4, post3.next_post_id)
    assert_equal(3, post4.prev_post_id)
    assert_nil(post4.next_post_id)
  end

  def test_remove_post_from_middle
    pool = create_pool
    add_posts(pool)

    pool.remove_post(2)
    assert_equal(3, pool.post_count)
    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    post3 = find_post(pool, 3)
    post4 = find_post(pool, 4)
    assert(!post2.active)
    assert_nil(post1.prev_post_id)
    assert_equal(3, post1.next_post_id)
    assert_equal(1, post3.prev_post_id)
    assert_equal(4, post3.next_post_id)
    assert_equal(3, post4.prev_post_id)
    assert_nil(post4.next_post_id)
  end

  def test_remove_post_from_tail
    pool = create_pool
    add_posts(pool)

    pool.remove_post(4)
    assert_equal(3, pool.post_count)
    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    post3 = find_post(pool, 3)
    post4 = find_post(pool, 4)
    assert(!post4.active)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_nil(post3.next_post_id)
  end

  def test_add_post
    pool = create_pool
    pool.add_post(1)
    post1 = find_post(pool, 1)
    assert_not_nil(post1)
    assert_equal(1, pool.post_count)
    assert_equal("1", post1.sequence)
    assert_equal(nil, post1.master)
    assert_equal(nil, post1.slave)
    assert_nil(post1.prev_post_id)
    assert_nil(post1.next_post_id)

    pool.add_post(2)
    post1.reload
    post2 = find_post(pool, 2)
    assert_not_nil(post2)
    assert_equal(2, pool.post_count)
    assert_equal("1", post1.sequence)
    assert_equal("2", post2.sequence)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(1, post2.prev_post_id)
    assert_nil(post2.next_post_id)

    pool.add_post(3)
    post1.reload
    post2.reload
    post3 = find_post(pool, 3)
    assert_not_nil(post3)
    assert_equal(3, pool.post_count)
    assert_equal("1", post1.sequence)
    assert_equal("2", post2.sequence)
    assert_equal("3", post3.sequence)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(1, post2.prev_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_nil(post3.next_post_id)

    pool.add_post(4)
    post1.reload
    post2.reload
    post3.reload
    post4 = find_post(pool, 4)
    assert_not_nil(post4)
    assert_equal(4, pool.post_count)
    assert_equal("1", post1.sequence)
    assert_equal("2", post2.sequence)
    assert_equal("3", post3.sequence)
    assert_equal("4", post4.sequence)
    assert_nil(post1.prev_post_id)
    assert_equal(2, post1.next_post_id)
    assert_equal(1, post2.prev_post_id)
    assert_equal(3, post2.next_post_id)
    assert_equal(2, post3.prev_post_id)
    assert_equal(4, post3.next_post_id)
    assert_equal(3, post4.prev_post_id)
    assert_nil(post4.next_post_id)
  end

  def test_add_duplicate
    assert_raise(Pool::PostAlreadyExistsError) do
      pool = create_pool
      add_posts(pool)
      pool.add_post(1)
    end
  end

  def test_destroy
    pool = create_pool
    pool.add_post(1)
    pool.add_post(2)
    pool.destroy
    assert_nil(PoolPost.find(:first, :conditions => ["pool_id = ? AND post_id = ?", pool.id, 1]))
    assert_nil(PoolPost.find(:first, :conditions => ["pool_id = ? AND post_id = ?", pool.id, 2]))
  end

  # Check validity of all posts after each operation.
  def check_consistency
    PoolPost.find(:all).each { |pp|
      if pp.active
        # An active post must never have a master.
        assert_equal(nil, pp.master_id)
      end

      if not pp.active
        # An inactive post must never have a slave.
        assert_equal(nil, pp.slave_id)
      end

      if pp.master
        assert_equal(pp.master.slave_id, pp.id)
        assert_equal(pp.master.sequence, pp.sequence)
      end

      if pp.slave
        assert_equal(pp.slave.master_id, pp.id)
        assert_equal(pp.slave.sequence, pp.sequence)
      end
    }
  end

  # Test that parenting a post that's in a pool creates the slave pool post.
  def test_master_parenting_existing
    pool = create_pool
    pool.add_post(1, { :sequence => 100 })
    post1 = find_post(pool, 1)
    check_consistency

    # Give the post in the pool a parent; this should add the parent to the pool as
    # a slave post with the same sequence number.
    Post.find(1).update_attributes(:parent_id => 2)
    post1.reload
    post2 = find_post(pool, 2)
    assert_equal(post2.id, post1.slave_id)
    assert_equal(post1.id, post2.master_id)
    assert_equal(false, post2.active)
    check_consistency

    # Changing the sequence number of the master should update the sequence of the slave post.
    post1.update_attributes(:sequence => "105")
    post2.reload
    assert_equal("105", post1.sequence)
    check_consistency

    # Remove the parent.  This should detach the slave post.
    Post.find(1).update_attributes(:parent_id => nil)
    post1.reload
    post2.reload
    assert_equal(nil, post1.slave_id)
    assert_equal(nil, post2.master_id)
    assert_equal(false, post2.active)
    check_consistency

    # Re-add the parent.
    Post.find(1).update_attributes(:parent_id => 2)
    post1.reload
    post2.reload
    assert_equal(post2.id, post1.slave_id)
    assert_equal(post1.id, post2.master_id)
    assert_equal(false, post2.active)
    check_consistency

    # Deactivate the parent.  This should detach and deactivate the slave post.
    post1.update_attributes(:active => false)
    post1.reload
    post2.reload
    assert_equal(nil, post1.slave_id)
    assert_equal(nil, post2.master_id)
    assert_equal(false, post2.active)
    check_consistency

    # Reactivate the parent.
    post1.update_attributes(:active => true)
    post1.reload
    post2.reload
    assert_equal(post2.id, post1.slave_id)
    assert_equal(post1.id, post2.master_id)
    assert_equal(false, post2.active)
    check_consistency

    # Activate the child.  This explicitly adds the post to the pool, which will detach
    # it from the master and set it active.
    post2.update_attributes(:active => true)
    post1.reload
    post2.reload
    assert_equal(nil, post1.slave_id)
    assert_equal(nil, post2.master_id)
    assert_equal(true, post2.active)
    check_consistency

    # Deactivate the child again.
    post2.update_attributes(:active => false)
    post1.reload
    post2.reload
    assert_equal(post2.id, post1.slave_id)
    assert_equal(post1.id, post2.master_id)
    assert_equal(false, post2.active)
    check_consistency
  end

  # Test that adding a post to a pool that has a parenting creates the slave pool post.
  def test_master_already_parented
    Post.find(1).update_attributes(:parent_id => 2)

    pool = create_pool
    pool.add_post(1, { :sequence => 100 })
    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    assert_equal(post2.id, post1.slave_id)
    assert_equal(post1.id, post2.master_id)
  end

  def test_master_ineligible
    pool = create_pool
    pool.add_post(1, { :sequence => 100 })
    post1 = find_post(pool, 1)
    check_consistency

    # Add post #2 explicitly.
    Post.find(1).update_attributes(:parent_id => nil)
    pool.add_post(2, { :sequence => 200 })
    post2 = find_post(pool, 2)
    check_consistency

    # Parenting the posts should now do nothing, because post #2 has been added explicitly
    # and is no longer eligible to be a slave post.
    Post.find(1).update_attributes(:parent_id => 2)
    post1.reload
    post2.reload
    assert_equal(nil, post1.slave_id)
    assert_equal(nil, post1.master_id)
    assert_equal(nil, post2.slave_id)
    assert_equal(nil, post2.master_id)
    check_consistency
  end

  def test_master_multiple_parents
    # Set both posts 1 and 2 in the pool to the same parent.
    pool = create_pool
    pool.add_post(1, { :sequence => 100 })
    pool.add_post(2, { :sequence => 200 })

    Post.find(1).update_attributes(:parent_id => 3)
    Post.find(2).update_attributes(:parent_id => 3)
    check_consistency

    post1 = find_post(pool, 1)
    post2 = find_post(pool, 2)
    post3 = find_post(pool, 3)

    # When multiple posts in a pool have the same parent (and the parent is not
    # in the pool explicitly), the parent becomes the slave of one of the two
    # posts, but which one is not defined.
    assert(post3.master_id == post1.id || post3.master_id == post2.id)
    master = (post3.master_id == post1.id ? post1 : post2)
    not_master = (post3.master_id == post1.id ? post2 : post1)
    master.reload
    not_master.reload
    assert_equal(master.slave_id, post3.id)
    assert_equal(master.sequence, post3.sequence)
    assert_nil(not_master.slave_id)

    # When we unparent the post that became the master, the remaining child post will
    # become the new master.
    Post.find(master.post_id).update_attributes(:parent_id => nil)
    post3.reload
    master.reload
    not_master.reload
    assert_equal(not_master.slave_id, post3.id)
    assert_equal(not_master.sequence, post3.sequence)
    assert_nil(master.slave_id)
    check_consistency
  end

  def test_access
    pool = create_pool
    assert_raise(Pool::AccessDeniedError) do
      pool.add_post(1, :user => User.find(4))
    end
    assert_nothing_raised do
      pool.add_post(1, :user => User.find(2))
    end
    assert_raise(Pool::AccessDeniedError) do
      pool.remove_post(1, :user => User.find(4))
    end
    assert_nothing_raised do
      pool.remove_post(1, :user => User.find(2))
    end
  end
end
