@PostUploadForm = (form, progress) ->
  XHRLevel2 = 'XMLHttpRequest' of window and (new XMLHttpRequest).upload != null and (new XMLHttpRequest).upload != undefined
  SupportsFormData = 'FormData' of window
  if !XHRLevel2 or !SupportsFormData
    return
  @form_element = form
  @cancel_element = @form_element.down('.cancel')
  @progress = progress
  @document_title = document.documentElement.down('TITLE')
  @document_title_orig = @document_title.textContent
  @current_request = null
  @form_element.on 'submit', @form_submit_event.bindAsEventListener(this)
  @cancel_element.on 'click', @click_cancel.bindAsEventListener(this)
  keypress_event_name = if window.opera or Prototype.Browser.Gecko then 'keypress' else 'keydown'
  document.on keypress_event_name, @document_keydown_event.bindAsEventListener(this)
  return

PostUploadForm::set_progress = (f) ->
  percent = f * 100
  @progress.down('.upload-progress-bar-fill').style.width = percent + '%'
  @document_title.textContent = @document_title_orig + ' (' + percent.toFixed(0) + '%)'
  return

PostUploadForm::request_starting = ->
  @form_element.down('.submit').hide()
  @cancel_element.show()
  @progress.show()
  document.documentElement.addClassName 'progress'
  return

PostUploadForm::request_ending = ->
  @form_element.down('.submit').show()
  @cancel_element.hide()
  @progress.hide()
  @document_title.textContent = @document_title_orig
  document.documentElement.removeClassName 'progress'
  return

PostUploadForm::document_keydown_event = (e) ->
  key = e.charCode
  if !key
    key = e.keyCode

  ### Opera ###

  if key != Event.KEY_ESC
    return
  @cancel()
  return

PostUploadForm::click_cancel = (e) ->
  e.stop()
  @cancel()
  return

PostUploadForm::form_submit_event = (e) ->

  ### This submit may have been stopped by User.run_login_onsubmit. ###

  if e.stopped
    return
  if @current_request != null and @current_request != undefined
    return
  $('post-exists').hide()
  $('post-upload-error').hide()

  ### If the files attribute isn't supported, or we have no file (source upload), use regular
  # form submission. 
  ###

  post_file = $('post_file')
  if post_file.files == null or post_file.files == undefined or post_file.files.length == 0
    return
  e.stop()
  @set_progress 0
  @request_starting()
  form_data = new FormData(@form_element)
  onprogress = ((e) ->
    done = e.loaded
    total = e.total
    @set_progress if total then done / total else 1
    return
  ).bind(this)
  @current_request = new (Ajax.Request)('/post/create.json',
    contentType: null
    method: 'post'
    postBody: form_data
    onCreate: (resp) ->
      xhr = resp.request.transport
      xhr.upload.onprogress = onprogress
      return
    onComplete: ((resp) ->
      @current_request = null
      @request_ending()
      json = resp.responseJSON
      if !json
        return
      if !json.success
        if json.location
          a = $('post-exists-link')
          a.setTextContent 'post #' + json.post_id
          a.href = json.location
          $('post-exists').show()
          return
        $('post-upload-error').setTextContent json.reason
        $('post-upload-error').show()
        return

      ### If a post/similar link was given and similar results exists, go to them.  Otherwise,
      # go to the new post. 
      ###

      target = json.location
      if json.similar_location and json.has_similar_hits
        target = json.similar_location
      window.location.href = target
      return
    ).bind(this))
  return

### Cancel the running request, if any. ###

PostUploadForm::cancel = ->
  if @current_request == null or @current_request == undefined
    return

  ### Don't clear this.current_request; it'll be done by the onComplete callback. ###

  @current_request.transport.abort()
  return

###
# When file_field is changed to an image, run an image search and put a summary in
# results.
###

@UploadSimilarSearch = (file_field, results) ->
  if !ThumbnailUserImage
    return
  @file_field = file_field
  @results = results
  file_field.on 'change', @field_changed_event.bindAsEventListener(this)
  return

UploadSimilarSearch::field_changed_event = (event) ->
  @results.hide()
  if @file_field.files == null or @file_field.files == undefined or @file_field.files.length == 0
    return
  @results.innerHTML = 'Searching...'
  @results.show()
  file = @file_field.files[0]
  similar = new ThumbnailUserImage(file, @thumbnail_complete.bind(this))
  return

UploadSimilarSearch::thumbnail_complete = (result) ->
  if !result.success
    @results.innerHTML = 'Image load failed.'
    @results.show()
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
    onComplete: ((resp) ->
      @results.innerHTML = ''
      @results.show()
      json = resp.responseJSON
      if !json.success
        @results.innerHTML = json.reason
        return
      if json.posts.length > 0
        posts = []
        shown_posts = 3
        json.posts.slice(0, shown_posts).each (post) ->
          url = undefined
          if User.get_use_browser()
            url = '/post/browse#' + post.id
          else
            url = '/post/show/' + post.id
          s = '<a href=\'' + url + '\'>post #' + post.id + '</a>'
          posts.push s
          return
        post_links = posts.join(', ')
        see_all = '<a href=\'/post/similar?search_id=' + json.search_id + '\'>(see all)</a>'
        html = 'Similar posts ' + see_all + ': ' + post_links
        if json.posts.length > shown_posts
          remaining_posts = json.posts.length - shown_posts
          html += ' (' + remaining_posts + ' more)'
        @results.innerHTML = html
      else
        @results.innerHTML = 'No similar posts found.'
      return
    ).bind(this))
  return
