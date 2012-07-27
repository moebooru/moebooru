# Start Post transition from prototypejs.

# This line actually useless since Coffeescript force 
# scoped closure for each javascript translation.
# Can't access global Post here.
Post = {} unless typeof Post == "object"

Post.highres = ($) ->
    if Post.inLargerVersion
        return false
    Post.inLargerVersion = true
    img = $("#image")
    large_image = $("#highres-show").attr("href")
    w = img.attr("large_width")
    h = img.attr("large_height")
    img = img.detach()
    img.attr("src", "")
    img.attr("width", w)
    img.attr("height", h)
    img.attr("src", large_image)
    img.insertAfter('#note-container')
    return false

# Post.highres patch for #image
# Still have to pass $ around manually.
# XXX: Centralized .ready (?)
jQuery ($) ->
    $("#highres-show").on "click", () ->
        Post.highres($)
