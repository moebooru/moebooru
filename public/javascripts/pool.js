Pool = {
  pools: new Hash(),
  register: function(pool)
  {
    Pool.pools.set(pool.id, pool);
  },

  register_pools: function(pools)
  {
    if(pools != null)
      pools.each(function(pool) { Pool.register(pool); });
  },

  register_pool_posts: function(pool_posts, posts)
  {
    /*
     * pool_post is an array of individual posts in pools.  It contains only data for posts
     * listed in posts.
     *
     * This means that a pool_post not existing in pool_posts only indicates the post is
     * no longer in the pool only if that post is listed in posts.
     *
     * We don't need to clear the pool_posts entry in posts, because the posts registered
     * by this function are always newly registered via Post.register_resp; pool_posts is
     * already empty.
     */
    pool_posts.each(function(pool_post) {
      var post = Post.posts.get(pool_post.post_id);
      if(post)
      {
        if(!post.pool_posts)
          post.pool_posts = new Hash();
        post.pool_posts.set(pool_post.pool_id, pool_post);
      }
    });

  },

  can_edit_pool: function(pool)
  {
    if(!User.is_member_or_higher())
      return false;

   return pool.is_public || pool.user_id == User.get_current_user_id();
  },

  add_post: function(post_id, pool_id) {
    notice("Adding to pool...")

    new Ajax.Request("/pool/add_post.json", {
      parameters: {
        "post_id": post_id,
        "pool_id": pool_id
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON
      
        if (resp.success) {
          notice("Post added to pool")
        } else {
          notice("Error: " + resp.reason)        
        }
      }
    })
  },

  remove_post: function(post_id, pool_id) {
    var complete = function()
    {
      notice("Post removed from pool")
      if($("p" + post_id))
        $("p" + post_id).addClassName("deleted");
      if($("pool" + pool_id))
        $("pool" + pool_id).remove()            
    }

    Post.make_request('/pool/remove_post.json', { "post_id": post_id, "pool_id": pool_id }, complete);
  },

  transfer_post: function(old_post_id, new_post_id, pool_id, sequence)
  {
    Post.update_batch(
      [{ id: old_post_id, tags: "-pool:" + pool_id, old_tags: "" },
       { id: new_post_id, tags: "pool:" + pool_id + ":" + sequence, old_tags: "" }],
      function() {
        notice("Pool post transferred to parent")

	/* We might be on the parent or child, which will do different things to
	 * the pool status display.  Just reload the page. */
	document.location.reload();
      }
    );
  },

  detach_post: function(post_id, pool_id, is_parent)
  {
    Post.update_batch(
      [{ id: post_id, tags: "-pool:" + pool_id, old_tags: "" }],
      function() {
        notice("Post detached")
        if(is_parent) {
          var elem = $("pool-detach-" + pool_id + "-" + post_id);
          if(elem)
            elem.remove()
        } else {
          if($("pool" + pool_id))
            $("pool" + pool_id).remove()
        }
      }
    );
  },

  /* This matches PoolPost.pretty_sequence. */
  post_pretty_sequence: function(sequence)
  {
    if(sequence.match(/^[0-9]+.*/))
      return "#" + sequence;
    else
      return "\"" + sequence + "\"";
  },

  change_sequence: function(post_id, pool_id, old_sequence)
  {
    new_sequence = prompt("Please enter the new page number:", old_sequence);
    if(new_sequence == null)
      return;
    if(new_sequence.indexOf(" ") != -1)
    {
      notice("Invalid page number");
      return;
    }

    Post.update_batch(
      [{ id: post_id, tags: "pool:" + pool_id + ":" + new_sequence, old_tags: "" }],
      function() {
        notice("Post updated")
        var elem = $("pool-seq-" + pool_id);
        if(!Object.isUndefined(elem.innerText))
          elem.innerText = Pool.post_pretty_sequence(new_sequence);
        else
          elem.textContent = Pool.post_pretty_sequence(new_sequence);
      }
    );
  }
}
