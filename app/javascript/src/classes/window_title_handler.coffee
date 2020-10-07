# Update the window title when the display changes.
class window.WindowTitleHandler
  constructor: ->
    @searched_tags = ''
    @post_id = null
    @post_frame = null
    @pool = null
    document.on 'viewer:searched-tags-changed', (e) =>
      @searched_tags = e.memo.tags ? ''
      @update()

    document.on 'viewer:displayed-post-changed', (e) =>
      @post_id = e.memo.post_id
      @post_frame = e.memo.post_id
      @update()

    document.on 'viewer:displayed-pool-changed', (e) =>
      @pool = e.memo.pool
      @update()

    @update()


  update: =>
    if @pool
      post = Post.posts.get(@post_id)
      title = @pool.name.replace(/_/g, ' ')

      if post?.pool_posts
        pool_post = post.pool_posts[@pool.id]
        if pool_post
          sequence = pool_post.sequence
          title += ' '
          if sequence.match(/^[0-9]/)
            title += '#'
          title += sequence
    else
      title = "/#{@searched_tags.replace(/_/g, ' ')}"

    title += ' - Browse'
    document.title = title
