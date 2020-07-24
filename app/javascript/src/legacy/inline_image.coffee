window.InlineImage =
  mouse_down: null
  zoom_levels: [
    1.0
    1.5
    2.0
    4.0
  ]
  get_zoom: (level) ->
    if level >= 0
      InlineImage.zoom_levels[level]
    else
      1 / InlineImage.zoom_levels[-level]
  register: (id, data) ->
    container = $(id)
    data.html_id = id
    container.inline_image = data

    ### initted is set to true after the image has been opened and the large images
    # inside have been created by expand(). 
    ###

    data.initted = false
    data.expanded = false
    data.toggled_from = null
    data.current = -1
    data.zoom_level = 0
    ui_html = ''
    if data.images.length > 1
      idx = 0
      while idx < data.images.length
        # html_id looks like "inline-123-456".  Mark the button for each individual image as "inline-123-456-2".
        button_id = data.html_id + '-' + idx
        text = data.images[idx].description.escapeHTML()
        if text == ''
          text = '#' + idx + 1
        ui_html += '<a href=\'#\' id=\'' + button_id + '\' class=\'select-image\' onclick=\'InlineImage.show_image_no("' + data.html_id + '", ' + idx + '); return false;\'>' + text + '</a>'
        ++idx
    ui_html += '<a href=\'#\' class=\'select-image\' onclick=\'InlineImage.zoom("' + data.html_id + '", +1); return false;\'>+</a>'
    ui_html += '<a href=\'#\' class=\'select-image\' onclick=\'InlineImage.zoom("' + data.html_id + '", -1); return false;\'>-</a>'
    zoom_id = data.html_id + '-zoom'
    ui_html += '<a href=\'#\' id=\'' + zoom_id + '\' class=\'select-image\' onclick=\'InlineImage.zoom("' + data.html_id + '", 0); return false;\'>100%</a>'
    ui_html += '<a href=\'#\' class=\'select-image\' onclick=\'InlineImage.close("' + data.html_id + '"); return false;\'>Close</a>'
    ui_html += '<a href=\'/inline/edit/' + data.id + '\' class=\'edit-link\'>Image&nbsp;#' + data.id + '</a>'
    container.down('.expanded-image-ui').innerHTML = ui_html
    container.down('.inline-thumb').observe 'click', (e) ->
      e.stop()
      InlineImage.expand data.html_id
      return
    container.observe 'dblclick', (e) ->
      e.stop()
      return
    viewer_img = container.down('.main-inline-image')

    ### If the expanded image has more than one image to choose from, clicking it will
    # temporarily show the next image.  Only show a pointer cursor if this is available. 
    ###

    if data.images.length > 1
      viewer_img.addClassName 'clickable'
    viewer_img.observe 'mousedown', (e) ->
      if e.button != 0
        return
      data.toggled_from = data.current
      idx = (data.current + 1) % data.images.length
      InlineImage.show_image_no data.html_id, idx
      InlineImage.mouse_down = data

      ### We need to stop the event, so dragging the mouse after clicking won't turn it
      # into a drag in Firefox.  If that happens, we won't get the mouseup. 
      ###

      e.stop()
      return
    return
  init: ->

    ### Mouseup events aren't necessarily sent to the same element that received the mousedown,
    # so we need to track which element received a mousedown and handle mouseup globally. 
    ###

    document.observe 'mouseup', (e) ->
      if e.button != 0
        return
      if !InlineImage.mouse_down?
        return
      e.stop()
      data = InlineImage.mouse_down
      InlineImage.mouse_down = null
      InlineImage.show_image_no data.html_id, data.toggled_from
      data.toggled_from = null
      return
    return
  expand: (id) ->
    container = $(id)
    data = container.inline_image
    data.expanded = true
    if !data.initted
      data.initted = true
      images = data['images']
      img_html = ''
      idx = 0
      while idx < data.images.length
        image = images[idx]
        width = undefined
        height = undefined
        src = undefined
        if image['sample_width']
          src = image['sample_url']
        else
          src = image['file_url']
        img_id = data.html_id + '-img-' + idx
        img_html += '<img src=\'' + src + '\' id=\'' + img_id + '\' width=' + width + ' height=' + height + ' style=\'display: none;\'>'
        ++idx
      viewer_img = container.down('.main-inline-image')
      viewer_img.innerHTML = img_html
    container.down('.inline-thumb').hide()
    InlineImage.show_image_no data.html_id, 0
    container.down('.expanded-image').show()
    # container.down(".expanded-image").scrollIntoView();
    return
  close: (id) ->
    container = $(id)
    data = container.inline_image
    data.expanded = false
    container.down('.expanded-image').hide()
    container.down('.inline-thumb').show()
    return
  show_image_no: (id, idx) ->
    container = $(id)
    data = container.inline_image
    images = data['images']
    image = images[idx]
    zoom = InlineImage.get_zoom(data.zoom_level)

    ### We need to set innerHTML rather than just setting attributes, so the changes happen
    # atomically.  Otherwise, Firefox will apply the width and height changes before source,
    # and flicker the old image at the new image's dimensions. 
    ###

    width = undefined
    height = undefined
    if image['sample_width']
      width = image['sample_width'] * zoom
      height = image['sample_height'] * zoom
    else
      width = image['width'] * zoom
      height = image['height'] * zoom
    width = width.toFixed(0)
    height = height.toFixed(0)
    if data.current != idx
      old_img_id = data.html_id + '-img-' + data.current
      old_img = $(old_img_id)
      if old_img
        old_img.hide()
    img_id = data.html_id + '-img-' + idx
    img = $(img_id)
    if img
      img.width = width
      img.height = height
      img.show()
    if data.current != idx
      new_button = $(data.html_id + '-' + idx)
      if new_button
        new_button.addClassName 'selected-image-tab'
      old_button = $(data.html_id + '-' + data.current)
      if old_button
        old_button.removeClassName 'selected-image-tab'
      data.current = idx
    return
  zoom: (id, dir) ->
    container = $(id)
    data = container.inline_image
    if dir == 0
      data.zoom_level = 0
    else
      data.zoom_level += dir
    if data.zoom_level > InlineImage.zoom_levels.length - 1
      data.zoom_level = InlineImage.zoom_levels.length - 1
    if data.zoom_level < -InlineImage.zoom_levels.length + 1
      data.zoom_level = -InlineImage.zoom_levels.length + 1

    ### Update the zoom level. ###

    zoom_id = data.html_id + '-zoom'
    zoom = InlineImage.get_zoom(data.zoom_level) * 100
    $(zoom_id).update zoom.toFixed(0) + '%'
    InlineImage.show_image_no id, data.current
    return
