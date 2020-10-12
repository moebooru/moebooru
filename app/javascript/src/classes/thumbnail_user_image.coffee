# This is a shared pool to be used by all instances
image_pool = null

# file must be a Blob object.  Create and return a thumbnail of the image.
# Perform an image search using post/similar.
#
# On completion, onComplete(result) will be called, where result is an object with
# these properties:
#
# success: true or false.
#
# On failure:
# aborted: true if failure was due to a user abort.
# chromeFailure: If true, the image loaded but was empty.  Chrome probably ran out
# of memory, but the selected file may be a valid image.
#
# On success:
# canvas: On success, the canvas containing the thumbnailed image.
#
export default class ThumbnailUserImage
  constructor: (file, onComplete) ->
    # Create the shared image pool, if we havn't yet.
    image_pool ?= new ImgPoolHandler
    @file = file
    @canvas = create_canvas_2d()
    @image = image_pool.get()
    @onComplete = onComplete
    @url = URL.createObjectURL(@file)
    @image.on 'load', @image_load_event
    @image.on 'abort', @image_abort_event
    @image.on 'error', @image_error_event
    document.documentElement.addClassName 'progress'
    @image.src = @url
    return

  # Cancel any running request.  The onComplete callback will not be called.
  # The object must not be reused.
  destroy: ->
    document.documentElement.removeClassName 'progress'
    @onComplete = null
    @image.stopObserving()
    image_pool.release @image
    @image = null
    if @url?
      URL.revokeObjectURL @url
      @url = null
    return

  completed: (result) ->
    if @onComplete
      @onComplete result
    @destroy()
    return

  # When the image finishes loading after form_submit_event sets it, update the canvas
  # thumbnail from it.
  image_load_event: (e) =>
    # Reduce the image size to thumbnail resolution.
    width = @image.width
    height = @image.height
    max_width = 128
    max_height = 128
    ratio = undefined
    if width > max_width
      ratio = max_width / width
      height *= ratio
      width *= ratio
    if height > max_height
      ratio = max_height / height
      height *= ratio
      width *= ratio
    width = Math.round(width)
    height = Math.round(height)

    # Set the canvas to the image size we want.
    canvas = @canvas
    canvas.width = width
    canvas.height = height

    # Blit the image onto the canvas.
    ctx = canvas.getContext('2d')

    # Clear the canvas, so check_image_contents can check that the data was correctly loaded.
    ctx.clearRect 0, 0, canvas.width, canvas.height
    ctx.drawImage @image, 0, 0, canvas.width, canvas.height
    if !@check_image_contents()
      @completed
        success: false
        chromeFailure: true
      return
    @completed
      success: true
      canvas: @canvas
    return

  # Work around a Chrome bug.  When very large images fail to load, we still get
  # onload and the image acts like a loaded, completely transparent image, instead
  # of firing onerror.  This makes it difficult to tell if the image actually loaded
  # or not.  Check that the image loaded by looking at the results; reject the image
  # if it's completely transparent.
  check_image_contents: ->
    ctx = @canvas.getContext('2d')
    image = ctx.getImageData(0, 0, @canvas.width, @canvas.height)
    data = image.data

    # Iterate through the alpha components, and search for any nonzero value.
    idx = 3
    max_idx = image.width * image.height * 4
    while idx < max_idx
      if data[idx] != 0
        return true
      idx += 4
    false

  image_abort_event: (e) =>
    @completed
      success: false
      aborted: true
    return

  # This happens on normal errors, usually because the file isn't a supported image.
  image_error_event: (e) =>
    @completed success: false
    return
