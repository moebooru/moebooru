$ = jQuery

###
# Creating and deleting IMG nodes seems to cause memory leaks in WebKit, but
# there are also reports that keeping the same node and replacing src can cause
# memory leaks (also in WebKit).
#
# So we don't have to depend on doing one or the other in other code, abstract
# this.  Use ImgPool.get() and ImgPool.release() to retrieve a new IMG node and
# return it.  We can choose here to either keep a pool, to avoid constantly
# creating new ones, or to throw them away and create new ones, to avoid changing
# src.
#
# This doesn't clear styles or any other properties.  To avoid leaking things from
# one type of image to another, use separate pools for each.
###
export default class ImgPoolHandlerWebKit
  constructor: ->
    @pool = []
    @pool_waiting = []


  blank_image_loaded_event: (event) =>
    img = event.target
    $(img).off 'load', @blank_image_loaded_event
    @pool_waiting = @pool_waiting.without(img)
    @pool.push img


  get: =>
    if @pool.length == 0
      # debug("No images in pool; creating blank");
      return document.createElement('img')
    # debug("Returning image from pool");
    @pool.pop()


  release: (img) =>
    ###
    # Replace the image with a blank, so when it's reused it doesn't show the previously-
    # loaded image until the new one is available.  Don't reuse the image until the blank
    # image is loaded.
    #
    # This also encourages the browser to abort any running download, so if we have a large
    # PNG downloading that we've cancelled it won't continue and download the whole thing.
    # Note that Firefox will stop a download if we do this, but not if we only remove an
    # image from the document.
    ###
    $(img).on 'load', @blank_image_loaded_event
    @pool_waiting.push img
    img.src = Vars.asset['blank.gif']
