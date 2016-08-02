window.Pool =
  pools: new Hash
  register: (pool) ->
    Pool.pools.set pool.id, pool
    return
  register_pools: (pools) ->
    if pools != null and pools != undefined
      pools.each (pool) ->
        Pool.register pool
        return
    return
  register_pool_posts: (pool_posts, posts) ->

    ###
    # pool_post is an array of individual posts in pools.  It contains only data for posts
    # listed in posts.
    #
    # This means that a pool_post not existing in pool_posts only indicates the post is
    # no longer in the pool only if that post is listed in posts.
    #
    # We don't need to clear the pool_posts entry in posts, because the posts registered
    # by this function are always newly registered via Post.register_resp; pool_posts is
    # already empty.
    ###

    pool_posts.each (pool_post) ->
      post = Post.posts.get(pool_post.post_id)
      if post
        if !post.pool_posts
          post.pool_posts = new Hash
        post.pool_posts.set pool_post.pool_id, pool_post
      return
    return
  can_edit_pool: (pool) ->
    if !User.is_member_or_higher()
      return false
    pool.is_public or pool.user_id == User.get_current_user_id()
  add_post: (post_id, pool_id) ->
    notice 'Adding to pool...'
    new (Ajax.Request)('/pool/add_post.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters:
        'post_id': post_id
        'pool_id': pool_id
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          notice 'Post added to pool'
        else
          notice 'Error: ' + resp.reason
        return
)
    return
  remove_post: (post_id, pool_id) ->

    complete = ->
      notice 'Post removed from pool'
      if $('p' + post_id)
        $('p' + post_id).addClassName 'deleted'
      if $('pool' + pool_id)
        $('pool' + pool_id).remove()
      return

    Post.make_request '/pool/remove_post.json', {
      'post_id': post_id
      'pool_id': pool_id
    }, complete
    return
  transfer_post: (old_post_id, new_post_id, pool_id, sequence) ->
    Post.update_batch [
      {
        id: old_post_id
        tags: '-pool:' + pool_id
        old_tags: ''
      }
      {
        id: new_post_id
        tags: 'pool:' + pool_id + ':' + sequence
        old_tags: ''
      }
    ], ->
      notice 'Pool post transferred to parent'

      ###We might be on the parent or child, which will do different things to
      # the pool status display.  Just reload the page. 
      ###

      document.location.reload()
      return
    return
  detach_post: (post_id, pool_id, is_parent) ->
    Post.update_batch [ {
      id: post_id
      tags: '-pool:' + pool_id
      old_tags: ''
    } ], ->
      notice 'Post detached'
      if is_parent
        elem = $('pool-detach-' + pool_id + '-' + post_id)
        if elem
          elem.remove()
      else
        if $('pool' + pool_id)
          $('pool' + pool_id).remove()
      return
    return
  post_pretty_sequence: (sequence) ->
    if sequence.match(/^[0-9]+.*/)
      '#' + sequence
    else
      '"' + sequence + '"'
  change_sequence: (post_id, pool_id, old_sequence) ->
    new_sequence = prompt('Please enter the new page number:', old_sequence)
    if new_sequence == null
      return
    if new_sequence.indexOf(' ') != -1
      notice 'Invalid page number'
      return
    Post.update_batch [ {
      id: post_id
      tags: 'pool:' + pool_id + ':' + new_sequence
      old_tags: ''
    } ], ->
      notice 'Post updated'
      elem = $('pool-seq-' + pool_id)
      if !Object.isUndefined(elem.innerText)
        elem.innerText = Pool.post_pretty_sequence(new_sequence)
      else
        elem.textContent = Pool.post_pretty_sequence(new_sequence)
      return
    return
