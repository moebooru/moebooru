window.History =
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
        History.last_click = -1
      History.mouse_is_down()
      event.stopPropagation()
      event.preventDefault()
      return
    ), true
    History.update()
    return
  add_change: (change_id, group_by_type, group_by_id, ids, user_id) ->
    History.checked.push
      id: change_id
      ids: ids
      group_by_type: group_by_type
      group_by_id: group_by_id
      user_id: user_id
      on: false
      row: $('r' + change_id)
    $('r' + change_id).observe 'mousedown', (e) ->
      History.mousedown(change_id, e)
      true
      return
    $('r' + change_id).observe 'mouseover', (e) ->
      History.mouseover(change_id, e)
      true
      return
    if $('r' + change_id).down('.id')
      $('r' + change_id).down('.id').observe 'click', (event) ->
        History.id_click change_id
        return
    $('r' + change_id).down('.author').observe 'click', (event) ->
      History.author_click change_id
      return
    $('r' + change_id).down('.change').observe 'click', (event) ->
      History.change_click change_id
      return
    return
  update: ->
    # Set selected flags on selected rows, and remove them from unselected rows.
    i = 0
    while i < History.checked.length
      row = History.checked[i].row
      if History.checked[i].on
        row.addClassName 'selected'
      else
        row.removeClassName 'selected'
      ++i
    if History.count_selected() > 0
      $('undo').removeClassName 'footer-disabled'
      $('redo').removeClassName 'footer-disabled'
    else
      $('undo').addClassName 'footer-disabled'
      $('redo').addClassName 'footer-disabled'
    return
  id_click: (id, event) ->
    id = History.get_row_by_id(id)
    $('search').value = History.checked[id].group_by_type.toLowerCase() + ':' + History.checked[id].group_by_id
    return
  author_click: (id, event) ->
    id = History.get_row_by_id(id)
    $('search').value = 'user:' + History.checked[id].user_id
    return
  change_click: (id, event) ->
    id = History.get_row_by_id(id)
    $('search').value = 'change:' + History.checked[id].id
    return
  count_selected: ->
    ret = 0
    i = 0
    while i < History.checked.length
      if History.checked[i].on
        ++ret
      ++i
    ret
  get_first_selected_row: ->
    i = 0
    while i < History.checked.length
      if History.checked[i].on
        return i
      ++i
    null
  get_row_by_id: (id) ->
    i = 0
    while i < History.checked.length
      if History.checked[i].id.toString() == id.toString()
        return i
      ++i
    -1
  set: (first, last, isOn) ->
    i = first
    loop
      History.checked[i].on = isOn
      if i.toString() == last.toString()
        break
      i += if last > first then +1 else -1
    return
  doc_mouseup: (event) ->
    History.dragging = false
    document.stopObserving 'mouseup', History.doc_mouseup
    return
  mouse_is_down: ->
    History.dragging = true
    document.observe 'mouseup', History.doc_mouseup
    return
  mousedown: (id, event) ->
    if !Event.isLeftClick(event)
      return
    History.mouse_is_down()
    i = History.get_row_by_id(id)
    if i == -1
      return
    first = null
    last = null
    if History.last_click != -1 and event.shiftKey
      first = History.last_click
      last = i
    else
      first = last = History.last_click = i
      History.checked[i].on = !History.checked[i].on
    isOn = History.checked[first].on
    if !event.ctrlKey
      History.set 0, History.checked.length - 1, false
    History.set first, last, isOn
    History.update()
    event.stopPropagation()
    event.preventDefault()
    return
  mouseover: (id, event) ->
    i = History.get_row_by_id(id)
    if i == -1
      return
    if History.last_click == -1
      History.last_click = i
    if !History.dragging
      return
    History.set 0, History.checked.length - 1, false
    first = History.last_click
    last = i
    this_click = i
    History.set first, last, true
    History.update()
    return
  undo: (redo) ->
    if History.count_selected() == 0
      return
    list = []
    i = 0
    while i < History.checked.length
      if !History.checked[i].on
        ++i
        continue
      list = list.concat(History.checked[i].ids)
      ++i
    if redo
      notice 'Reapplying...'
    else
      notice 'Undoing...'
    new (Ajax.Request)('/history/undo.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters:
        'id': list.join(',')
        'redo': if redo then 1 else 0
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          text = resp.errors
          if resp.successful > 0
            text.unshift if redo then 'Changes reapplied.' else 'Changes undone.'
          notice text.join('<br>')
        else
          notice 'Error: ' + resp.reason
        return
)
    return
