import ThumbnailUserImage from './thumbnail_user_image'

$ = jQuery

export default class SimilarWithThumbnailing
  constructor: (form) ->
    @_similar = null
    @_form = form
    @_forceFile = null
    $(@_form).on 'submit', @_onSubmit


  # Submit a post/similar request using the image currently in the canvas.
  _complete: (result) =>
    if result.chromeFailure
      notice 'The image failed to load; submitting normally...'
      @_forceFile = @_file

      # Resend the submit event.  Defer it, so the notice can take effect before we
      # navigate off the page.
      window.setTimeout =>
        $(@_form).submit()
      return
    if !result.success
      if !result.aborted
        alert 'The file couldn\'t be loaded.'
      return

    # Grab a data URL from the canvas; this is what we'll send to the server.

    $.ajax '/post/similar.json',
      method: 'POST'
      data:
        url: result.canvas.toDataURL()
      dataType: 'json'
    .done (resp) =>
      # Redirect to the search results.
      window.location.href = "/post/similar?search_id=#{resp.search_id}"
    .fail (xhr) =>
      notice "Error: #{xhr.responseJSON?.reason ? 'unknown error'}"

    return


  _onSubmit: (e) =>
    postFile = @_form.querySelector('#file')

    # If the files attribute isn't supported, or we have no file (source upload), use regular
    # form submission.
    return if !postFile.files? || postFile.files.length == 0

    # If we failed to load the image last time due to a silent Chrome error, continue with
    # the submission normally this time.
    file = postFile.files[0]
    if @_forceFile? && @_forceFile == file
      @_forceFile = null
      return

    e.preventDefault()

    @_similar?.destroy()
    @_similar = new ThumbnailUserImage(file, @_complete)

    return
