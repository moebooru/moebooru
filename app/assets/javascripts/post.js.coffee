# Start Post transition from prototypejs.
#

class Post
    constructor: ->
        @posts = {}

    highres: (large_src, img) ->
        width = img.attr 'large_width'
        height = img.attr 'large_height'
        img.hide()
        img.attr 'src', ''
        img.attr 'width', width
        img.attr 'height', height
        img.attr 'src', large_src
        img.show()
        false

    registerPosts: (posts) ->
        @current = posts[0] if posts.length == 1
        posts.forEach (p, idx, arr) =>
            p.tags = p.tags.match(/\S+/g) || []
            p.metatags = p.tags.clone()
            p.metatags.push "rating:" + p.rating[0]
            p.metatags.push "status:" + p.status
            @posts[p.id] = p
        false

    get: (post_id) ->
        @posts[post_id]


jQuery ($) ->
    post = new Post()
    Moebooru.attach('post', post)
    inLargerVersion = false

    Moe.on 'post:add', (e, data) ->
        post.registerPosts data

    # XXX: isn't this supposed to be called _only_ at '/post/show' ?
    $('.highres-show').on 'click', ->
        return false if inLargerVersion
        inLargerVersion = true
        $('#resized_notice').hide()
        if window.Note
            window.Note.all.invoke 'adjustScale'
        post.highres @href, $('#image')

    $('#post_tags').on 'keydown', (e) ->
        if e.which == 13
            $('#edit-form').submit()
