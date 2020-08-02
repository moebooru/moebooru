(($) ->

  Post = ->
    @posts = {}
    return

  Post.prototype =
    registerPosts: (posts) ->
      th = this
      if posts.length == 1
        @current = posts[0]
      posts.forEach (p, idx, arr) ->
        p.tags = p.tags.match(/\S+/g) or []
        p.metatags = p.tags.clone()
        p.metatags.push 'rating:' + p.rating[0]
        p.metatags.push 'status:' + p.status
        th.posts[p.id] = p
        return
      false
    get: (post_id) ->
      @posts[post_id]
  $ ->
    post = new Post
    inLargerVersion = false
    Moe.on 'post:add', (e, data) ->
      post.registerPosts data
      return
    $('.highres-show').on 'click', ->
      img = $('#image')
      w = img.attr('large_width')
      h = img.attr('large_height')
      if inLargerVersion
        return false
      inLargerVersion = true
      $('#resized_notice').hide()
      img.hide()
      img.attr 'src', ''
      img.attr 'width', w
      img.attr 'height', h
      img.attr 'src', @href
      img.show()
      notesManager.all.invoke 'adjustScale'
      false
    $('#post_tags').on 'keydown', (e) ->
      if e.which == 13
        e.preventDefault()
        $('#edit-form').submit()
      return
    return
  return
) jQuery
