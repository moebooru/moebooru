# When file_field is changed to an image, run an image search and put a summary in
# results.
window.UploadSimilarSearch = (file_field, results) ->
  if !ThumbnailUserImage
    return
  @file_field = file_field
  @results = results
  file_field.on 'change', @field_changed_event.bindAsEventListener(this)
  return

UploadSimilarSearch::field_changed_event = (event) ->
  @results.hide()
  if !@file_field.files? or @file_field.files.length == 0
    return
  @results.innerHTML = 'Searching...'
  @results.show()
  file = @file_field.files[0]
  similar = new ThumbnailUserImage(file, @thumbnail_complete.bind(this))
  return

UploadSimilarSearch::thumbnail_complete = (result) ->
  if !result.success
    @results.innerHTML = 'Image load failed.'
    @results.style.display = ''
    return

  jQuery.ajax '/post/similar.json',
    data:
      url: result.canvas.toDataURL()
    dataType: 'json'
    method: 'POST'
  .always =>
    @results.innerHTML = ''
    @results.style.display = ''
  .done (json) =>
    if json.posts.length > 0
      posts = []
      shownPosts = 3
      makeUrl =
          if User.get_use_browser()
            (post) => "/post/browse##{post.id}"
          else
            (post) => "/post/show/#{post.id}"
      posts = json.posts.slice(0, shownPosts).map (post) =>
        "<a href='#{makeUrl(post)}'>post ##{post.id}</a>"
      seeAll = "<a href='/post/similar?search_id='#{json.search_id}'>(see all)</a>"
      html = "Similar posts #{seeAll}: #{posts.join(', ')}"

      if json.posts.length > shownPosts
        remainingPosts = json.posts.length - shownPosts
        html += " (#{remainingPosts} more)"

      message = html
    else
      message = 'No similar posts found.'

    @results.innerHTML = message
  .fail (xhr) =>
    @results.innerHTML = xhr.responseJSON?.reason ? 'unknown error'
