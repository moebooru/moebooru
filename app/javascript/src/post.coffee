(($) ->

  $ ->
    inLargerVersion = false
    $('.highres-show').on 'click', ->
      img = $('#image')
      w = img.attr('large_width')
      h = img.attr('large_height')
      if inLargerVersion
        return false
      inLargerVersion = true
      $('#resized_notice').hide()
      img.hide()
      img.attr 'src', ''
      img.attr 'width', w
      img.attr 'height', h
      img.attr 'src', @href
      img.show()
      notesManager.all.invoke 'adjustScale'
      false
    $('#post_tags').on 'keydown', (e) ->
      if e.which == 13
        e.preventDefault()
        document.getElementById('edit-form').requestSubmit()
      return
    return
  return
) jQuery
