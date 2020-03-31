###
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
###

window.ThumbnailUserImage = (file, onComplete) ->

  ### Create the shared image pool, if we havn't yet. ###

  if ThumbnailUserImage.image_pool == null or ThumbnailUserImage.image_pool == undefined
    ThumbnailUserImage.image_pool = new ImgPoolHandler
  @file = file
  @canvas = create_canvas_2d()
  @image = ThumbnailUserImage.image_pool.get()
  @onComplete = onComplete
  @url = URL.createObjectURL(@file)
  @image.on 'load', @image_load_event.bindAsEventListener(this)
  @image.on 'abort', @image_abort_event.bindAsEventListener(this)
  @image.on 'error', @image_error_event.bindAsEventListener(this)
  document.documentElement.addClassName 'progress'
  @image.src = @url
  return

### This is a shared pool; for clarity, don't put it in the prototype. ###

ThumbnailUserImage.image_pool = null

### Cancel any running request.  The onComplete callback will not be called.
# The object must not be reused. 
###

ThumbnailUserImage::destroy = ->
  document.documentElement.removeClassName 'progress'
  @onComplete = null
  @image.stopObserving()
  ThumbnailUserImage.image_pool.release @image
  @image = null
  if @url != null and @url != undefined
    URL.revokeObjectURL @url
    @url = null
  return

ThumbnailUserImage::completed = (result) ->
  if @onComplete
    @onComplete result
  @destroy()
  return

### When the image finishes loading after form_submit_event sets it, update the canvas
# thumbnail from it. 
###

ThumbnailUserImage::image_load_event = (e) ->

  ### Reduce the image size to thumbnail resolution. ###

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

  ### Set the canvas to the image size we want. ###

  canvas = @canvas
  canvas.width = width
  canvas.height = height

  ### Blit the image onto the canvas. ###

  ctx = canvas.getContext('2d')

  ### Clear the canvas, so check_image_contents can check that the data was correctly loaded. ###

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

###
# Work around a Chrome bug.  When very large images fail to load, we still get
# onload and the image acts like a loaded, completely transparent image, instead
# of firing onerror.  This makes it difficult to tell if the image actually loaded
# or not.  Check that the image loaded by looking at the results; reject the image
# if it's completely transparent.
###

ThumbnailUserImage::check_image_contents = ->
  ctx = @canvas.getContext('2d')
  image = ctx.getImageData(0, 0, @canvas.width, @canvas.height)
  data = image.data

  ### Iterate through the alpha components, and search for any nonzero value. ###

  idx = 3
  max_idx = image.width * image.height * 4
  while idx < max_idx
    if data[idx] != 0
      return true
    idx += 4
  false

ThumbnailUserImage::image_abort_event = (e) ->
  @completed
    success: false
    aborted: true
  return

### This happens on normal errors, usually because the file isn't a supported image. ###

ThumbnailUserImage::image_error_event = (e) ->
  @completed success: false
  return

### If the necessary APIs aren't supported, don't use ThumbnailUserImage. ###

if !('URL' of window) or create_canvas_2d() == null
  window.ThumbnailUserImage = null

window.SimilarWithThumbnailing = (form) ->
  @similar = null
  @form = form
  @force_file = null
  form.on 'submit', @form_submit_event.bindAsEventListener(this)
  return

SimilarWithThumbnailing::form_submit_event = (e) ->
  post_file = @form.down('#file')

  ### If the files attribute isn't supported, or we have no file (source upload), use regular
  # form submission. 
  ###

  if post_file.files == null or post_file.files == undefined or post_file.files.length == 0
    return

  ### If we failed to load the image last time due to a silent Chrome error, continue with
  # the submission normally this time. 
  ###

  file = post_file.files[0]
  if @force_file and @force_file == file
    @force_file = null
    return
  e.stop()
  if @similar
    @similar.destroy()
  @similar = new ThumbnailUserImage(file, @complete.bind(this))
  return

### Submit a post/similar request using the image currently in the canvas. ###

SimilarWithThumbnailing::complete = (result) ->
  if result.chromeFailure
    notice 'The image failed to load; submitting normally...'
    @force_file = @file

    ### Resend the submit event.  Defer it, so the notice can take effect before we
    # navigate off the page. 
    ###

    (->
      @form.simulate_submit()
      return
    ).bind(this).defer()
    return
  if !result.success
    if !result.aborted
      alert 'The file couldn\'t be loaded.'
    return

  ### Grab a data URL from the canvas; this is what we'll send to the server. ###

  data_url = result.canvas.toDataURL()

  ### Create the FormData containing the thumbnail image we're sending. ###

  form_data = new FormData
  form_data.append 'url', data_url
  req = new (Ajax.Request)('/post/similar.json',
    method: 'post'
    postBody: form_data
    contentType: null
    onComplete: (resp) ->
      json = resp.responseJSON
      if !json.success
        notice json.reason
        return

      ### Redirect to the search results. ###

      window.location.href = '/post/similar?search_id=' + json.search_id
      return
)
  return

### If the necessary APIs aren't supported, don't use SimilarWithThumbnailing. ###

if !('FormData' of window) or !ThumbnailUserImage
  window.SimilarWithThumbnailing = null
