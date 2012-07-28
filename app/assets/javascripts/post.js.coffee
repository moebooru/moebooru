# Start Post transition from prototypejs.
#

class Post
    constructor: ->
        @inLargerVersion = false

    highres: (largeSource, img) ->
        return false if @inLargerVersion
        width = img.attr 'large_width'
        height = img.attr 'large_height'
        img.hide()
        img.attr 'src', ''
        img.attr 'width', width
        img.attr 'height', height
        img.attr 'src', largeSource
        img.show()
        @inLargerVersion = true
        return false


# Post.highres patch for #image
# XXX: Centralized .ready (?)
jQuery ($) ->
    post = new Post()
    $('.highres-show').on 'click', ->
        post.highres @href, $('#image')
        $('#resized_notice').hide()
        if window.Note
            window.Note.all.invoke 'adjustScale'
        false
