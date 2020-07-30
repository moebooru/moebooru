$ = jQuery

export default class Pool
  constructor: ->
    @pools = {}


  register: (pool) =>
    @pools[pool.id] = pool


  register_pools: (pools) =>
    return if !pools?

    @register pool for pool in pools


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
    for pool_post in pool_posts
      post = Post.posts.get(pool_post.post_id)

      continue if !post?

      post.pool_posts ?= {}
      post.pool_posts[pool_post.pool_id] = pool_post


  can_edit_pool: (pool) ->
    return false if !User.is_member_or_higher()

    pool.is_public || pool.user_id == User.get_current_user_id()


  add_post: (post_id, pool_id) ->
    notice "Adding to pool..."

    $.ajax "/pool/add_post.json",
      method: "POST"
      data:
        post_id: post_id
        pool_id: pool_id
      dataType: "json"

    .done (resp) ->
      notice "Post added to pool"

    .fail (xhr) ->
      reason = xhr.responseJSON?.reason ? 'unknown error'

      notice "Error: #{reason}"


  remove_post: (post_id, pool_id) ->
    callback = ->
      notice "Post removed from pool"
      $("#p#{post_id}").addClass "deleted"
      $("#pool#{pool_id}").remove()

    Post.make_request "/pool/remove_post.json",
      post_id: post_id
      pool_id: pool_id
      callback


  transfer_post: (old_post_id, new_post_id, pool_id, sequence) ->
    callback = ->
      notice "Pool post transferred to parent"

      # We might be on the parent or child, which will do different things to
      # the pool status display.  Just reload the page.
      document.location.reload()

    Post.update_batch [
      {
        id: old_post_id
        tags: "-pool:#{pool_id}"
        old_tags: ""
      }
      {
        id: new_post_id
        tags: "pool:#{pool_id}:#{sequence}"
        old_tags: ""
      }
    ], callback


  detach_post: (post_id, pool_id, is_parent) ->
    callback = ->
      notice "Post detached"
      if is_parent
        $("#pool-detach-#{pool_id}-#{post_id}").remove()
      else
        $("#pool-#{pool_id}").remove()


    Post.update_batch [{
      id: post_id
      tags: "-pool:#{pool_id}"
      old_tags: ""
    }], callback


  post_pretty_sequence: (sequence) ->
    if sequence.match(/^\d/)
      "##{sequence}"
    else
      '"' + sequence + '"'


  change_sequence: (post_id, pool_id, old_sequence) =>
    new_sequence = prompt("Please enter the new page number:", old_sequence)

    return if !new_sequence?

    if new_sequence.indexOf(" ") != -1
      notice "Invalid page number"
      return

    callback = =>
      notice "Post updated"
      $("#pool-seq-#{pool_id}").text @post_pretty_sequence(new_sequence)

    Post.update_batch [{
      id: post_id
      tags: "pool:#{pool_id}:#{new_sequence}"
      old_tags: ""
    }], callback
