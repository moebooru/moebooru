window.PostTagHistory =
  last_click: -1
  checked: []
  dragging: false
  init: ->
    # Watch mousedown events on the table itself, so clicking between table rows and dragging
    # doesn't misbehave.
    $('history').observe 'mousedown', ((event) ->
      if !event.shiftKey
        # Clear last_click, so dragging will extend from the next position crossed instead of
        # the previous position clicked.
        PostTagHistory.last_click = -1
      PostTagHistory.mouse_is_down()
      event.stopPropagation()
      event.preventDefault()
      return
    ), true
    PostTagHistory.update()
    return
  add_change: (id, post_id, user_id) ->
    PostTagHistory.checked.push
      id: id
      post_id: post_id
      user_id: user_id
      on: false
      row: $('r' + id)
    $('r' + id).observe 'mousedown', (e) ->
      PostTagHistory.mousedown(id, e)
      true
      return
    $('r' + id).observe 'mouseover', (e) ->
      PostTagHistory.mouseover(id, e)
      true
      return
    return
  update: ->
    # Set selected flags on selected rows, and remove them from unselected rows.
    i = 0
    while i < PostTagHistory.checked.length
      row = PostTagHistory.checked[i].row
      if PostTagHistory.checked[i].on
        row.addClassName 'selected'
      else
        row.removeClassName 'selected'
      ++i
    if PostTagHistory.count_selected() > 0
      $('undo').className = ''
    else
      $('undo').className = 'footer-disabled'
    if PostTagHistory.count_selected() == 1
      i = PostTagHistory.get_first_selected_row()
      $('revert').href = 'post_tag_history/revert?id=' + PostTagHistory.checked[i].id
      $('revert').className = ''
      $('post_id').value = PostTagHistory.checked[i].post_id
      $('user_name').value = PostTagHistory.checked[i].user_id
    else
      $('revert').href = '#'
      $('revert').className = 'footer-disabled'
    return
  count_selected: ->
    ret = 0
    i = 0
    while i < PostTagHistory.checked.length
      if PostTagHistory.checked[i].on
        ++ret
      ++i
    ret
  get_first_selected_row: ->
    i = 0
    while i < PostTagHistory.checked.length
      if PostTagHistory.checked[i].on
        return i
      ++i
    null
  get_row_by_id: (id) ->
    i = 0
    while i < PostTagHistory.checked.length
      if PostTagHistory.checked[i].id == id
        return i
      ++i
    null
  set: (first, last, isOn) ->
    i = first
    loop
      PostTagHistory.checked[i].on = isOn
      if i == last
        break
      i += if last > first then +1 else -1
    return
  doc_mouseup: (event) ->
    PostTagHistory.dragging = false
    document.stopObserving 'mouseup', PostTagHistory.doc_mouseup
    return
  mouse_is_down: ->
    PostTagHistory.dragging = true
    document.observe 'mouseup', PostTagHistory.doc_mouseup
    return
  mousedown: (id, event) ->
    if !Event.isLeftClick(event)
      return
    PostTagHistory.mouse_is_down()
    i = PostTagHistory.get_row_by_id(id)
    if !i?
      return
    first = null
    last = null
    if PostTagHistory.last_click != -1 and event.shiftKey
      first = PostTagHistory.last_click
      last = i
    else
      first = last = PostTagHistory.last_click = i
      PostTagHistory.checked[i].on = !PostTagHistory.checked[i].on
    isOn = PostTagHistory.checked[first].on
    if !event.ctrlKey
      PostTagHistory.set 0, PostTagHistory.checked.length - 1, false
    PostTagHistory.set first, last, isOn
    PostTagHistory.update()
    event.stopPropagation()
    event.preventDefault()
    return
  mouseover: (id, event) ->
    i = PostTagHistory.get_row_by_id(id)
    if !i
      return
    if PostTagHistory.last_click == -1
      PostTagHistory.last_click = i
    if !PostTagHistory.dragging
      return
    PostTagHistory.set 0, PostTagHistory.checked.length - 1, false
    first = PostTagHistory.last_click
    last = i
    this_click = i
    PostTagHistory.set first, last, true
    PostTagHistory.update()
    return
  undo: ->
    if PostTagHistory.count_selected() == 0
      return
    list = []
    i = 0
    while i < PostTagHistory.checked.length
      if !PostTagHistory.checked[i].on
        ++i
        continue
      list.push PostTagHistory.checked[i].id
      ++i
    notice 'Undoing...'
    new (Ajax.Request)('/post_tag_history/undo.json',
      parameters: 'id': list.join(',')
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          notice 'Changes undone.'
        else
          notice 'Error: ' + resp.reason
        return
)
    return
