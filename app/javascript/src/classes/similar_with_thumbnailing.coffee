class window.SimilarWithThumbnailing
  constructor: (form) ->
    @similar = null
    @form = form
    @force_file = null
    form.on 'submit', @form_submit_event
    return

  form_submit_event: (e) =>
    post_file = @form.down('#file')

    # If the files attribute isn't supported, or we have no file (source upload), use regular
    # form submission.
    if !post_file.files? or post_file.files.length == 0
      return

    # If we failed to load the image last time due to a silent Chrome error, continue with
    # the submission normally this time.
    file = post_file.files[0]
    if @force_file and @force_file == file
      @force_file = null
      return
    e.stop()
    if @similar
      @similar.destroy()
    @similar = new ThumbnailUserImage(file, @complete)
    return

  # Submit a post/similar request using the image currently in the canvas.
  complete: (result) =>
    if result.chromeFailure
      notice 'The image failed to load; submitting normally...'
      @force_file = @file

      # Resend the submit event.  Defer it, so the notice can take effect before we
      # navigate off the page.
      (->
        @form.simulate_submit()
        return
      ).bind(this).defer()
      return
    if !result.success
      if !result.aborted
        alert 'The file couldn\'t be loaded.'
      return

    # Grab a data URL from the canvas; this is what we'll send to the server.
    data_url = result.canvas.toDataURL()

    # Create the FormData containing the thumbnail image we're sending.
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

        # Redirect to the search results.
        window.location.href = '/post/similar?search_id=' + json.search_id
        return
  )
    return
