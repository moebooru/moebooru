# Start Post transition from prototypejs.
#

class Post
    constructor: ->
        @inLargerVersion = false
        @image = jQuery '#image'
        @width = @image.attr 'large_width'
        @height = @image.attr 'large_height'
        @largeSource = jQuery('#highres-show').attr 'href'

    highres: ->
        return false if @inLargerVersion
        @image.detach()
        @image.attr 'src', ''
        @image.attr 'width', @width
        @image.attr 'height', @height
        @image.attr 'src', @largeSource
        @image.insertAfter '#note-container'
        @inLargerVersion = true
        return false


# Post.highres patch for #image
# XXX: Centralized .ready (?)
jQuery ($) ->
    post = new Post()
    $('#highres-show').on 'click', ->
        post.highres()

