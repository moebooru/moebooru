# Start Post transition from prototypejs.

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
