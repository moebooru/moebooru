$ = jQuery

window.History =
  last_click: -1
  checked: []
  dragging: false


  init: ->
    # Watch mousedown events on the table itself, so clicking between table rows
    # and dragging doesn't misbehave.
    $('#history').on 'mousedown', (event) ->
      if !event.shiftKey
        # Clear last_click, so dragging will extend from the next position
        # crossed instead of the previous position clicked.
        History.last_click = -1
      History.mouse_is_down()
      event.stopPropagation()
      event.preventDefault()

    History.update()


  add_change: (change_id, group_by_type, group_by_id, ids, user_id) ->
    row = $("#r#{change_id}")

    History.checked.push
      id: change_id
      ids: ids
      group_by_type: group_by_type
      group_by_id: group_by_id
      user_id: user_id
      on: false
      row: row

    row.on 'mousedown', (e) ->
      History.mousedown(change_id, e)

    row.on 'mouseover', (e) ->
      History.mouseover(change_id, e)

    row.find('.id').on 'click', (event) ->
      History.id_click change_id

    row.find('.author').on 'click', (event) ->
      History.author_click change_id

    row.find('.change').on 'click', (event) ->
      History.change_click change_id


  update: ->
    # Set selected flags on selected rows, and remove them from unselected rows.
    for entry in History.checked
      row = entry.row
      if entry.on
        row.addClass 'selected'
      else
        row.removeClass 'selected'

    if History.count_selected() > 0
      $('#undo').removeClass 'footer-disabled'
      $('#redo').removeClass 'footer-disabled'
    else
      $('#undo').addClass 'footer-disabled'
      $('#redo').addClass 'footer-disabled'



  id_click: (id) ->
    id = History.get_row_by_id(id)
    entry = History.checked[id]
    $('#search').val "#{entry.group_by_type.toLowerCase()}:#{entry.group_by_id}"


  author_click: (id) ->
    id = History.get_row_by_id(id)
    $('#search').val "user:#{History.checked[id].user_id}"


  change_click: (id) ->
    id = History.get_row_by_id(id)
    $('#search').val "change:#{History.checked[id].id}"


  count_selected: ->
    ret = 0
    ret++ for entry in History.checked when entry.on

    ret


  get_first_selected_row: ->
    return i for entry, i in History.checked when entry.on

    # nothing found, return null
    null


  get_row_by_id: (id) ->
    for entry, i in History.checked
      return i if entry.id.toString() == id.toString()

    # nothing found, return -1
    -1


  set: (first, last, isOn) ->
    first = parseInt(first, 10)
    last = parseInt(last, 10)

    [first, last] = [last, first] if last < first

    for entry in History.checked[first..last]
      entry.on = isOn


  doc_mouseup: (event) ->
    History.dragging = false
    $(document).off 'mouseup', History.doc_mouseup


  mouse_is_down: ->
    History.dragging = true
    $(document).on 'mouseup', History.doc_mouseup


  mousedown: (id, event) ->
    # only for primary click
    return if event.which != 1

    History.mouse_is_down()
    i = History.get_row_by_id(id)

    # no row found?
    return if i == -1

    first = null
    last = null

    if History.last_click != -1 && event.shiftKey
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


  mouseover: (id, event) ->
    i = History.get_row_by_id(id)

    return if i == -1

    if History.last_click == -1
      History.last_click = i

    return if !History.dragging

    History.set 0, History.checked.length - 1, false
    first = History.last_click
    last = i
    this_click = i
    History.set first, last, true
    History.update()


  undo: (redo) ->
    return if History.count_selected() == 0

    list = []

    for entry in History.checked
      list = list.concat(entry.ids) if entry.on

    if redo
      notice 'Reapplying...'
    else
      notice 'Undoing...'

    $.ajax '/history/undo.json',
      method: 'POST'
      dataType: 'json'
      data:
        id: list.join(',')
        redo: if redo then 1 else 0
    .done (resp) ->
      text = resp.errors

      if resp.successful > 0
        mainMessage = "Changes #{if redo then 'reapplied' else 'undone'}."
        text.unshift mainMessage

      notice text.join('<br>')

    .fail (resp) ->
      notice "Error: #{resp.reason}"
