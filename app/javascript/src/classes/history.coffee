$ = jQuery

export default class History
  constructor: ->
    @last_click = -1
    @checked = []
    @dragging = false


  init: ->
    # Watch mousedown events on the table itself, so clicking between table rows
    # and dragging doesn't misbehave.
    $('#history').on 'mousedown', (event) =>
      if !event.shiftKey
        # Clear last_click, so dragging will extend from the next position
        # crossed instead of the previous position clicked.
        @last_click = -1
      @mouse_is_down()
      event.stopPropagation()
      event.preventDefault()

    @update()


  add_change: (change_id, group_by_type, group_by_id, ids, user_id) ->
    row = $("#r#{change_id}")

    @checked.push
      id: change_id
      ids: ids
      group_by_type: group_by_type
      group_by_id: group_by_id
      user_id: user_id
      on: false
      row: row

    row.on 'mousedown', (e) =>
      @mousedown(change_id, e)

    row.on 'mouseover', (e) =>
      @mouseover(change_id, e)

    row.find('.id').on 'click', (event) =>
      @id_click change_id

    row.find('.author').on 'click', (event) =>
      @author_click change_id

    row.find('.change').on 'click', (event) =>
      @change_click change_id


  update: ->
    # Set selected flags on selected rows, and remove them from unselected rows.
    for entry in @checked
      row = entry.row
      if entry.on
        row.addClass 'selected'
      else
        row.removeClass 'selected'

    if @count_selected() > 0
      $('#undo').removeClass 'footer-disabled'
      $('#redo').removeClass 'footer-disabled'
    else
      $('#undo').addClass 'footer-disabled'
      $('#redo').addClass 'footer-disabled'



  id_click: (id) ->
    id = @get_row_by_id(id)
    entry = @checked[id]
    $('#search').val "#{entry.group_by_type.toLowerCase()}:#{entry.group_by_id}"


  author_click: (id) ->
    id = @get_row_by_id(id)
    $('#search').val "user:#{@checked[id].user_id}"


  change_click: (id) ->
    id = @get_row_by_id(id)
    $('#search').val "change:#{@checked[id].id}"


  count_selected: ->
    ret = 0
    ret++ for entry in @checked when entry.on

    ret


  get_first_selected_row: ->
    return i for entry, i in @checked when entry.on

    # nothing found, return null
    null


  get_row_by_id: (id) ->
    for entry, i in @checked
      return i if entry.id.toString() == id.toString()

    # nothing found, return -1
    -1


  set: (first, last, isOn) ->
    first = parseInt(first, 10)
    last = parseInt(last, 10)

    [first, last] = [last, first] if last < first

    for entry in @checked[first..last]
      entry.on = isOn


  doc_mouseup: (event) =>
    @dragging = false
    $(document).off 'mouseup', @doc_mouseup


  mouse_is_down: ->
    @dragging = true
    $(document).on 'mouseup', @doc_mouseup


  mousedown: (id, event) ->
    # only for primary click
    return if event.which != 1

    @mouse_is_down()
    i = @get_row_by_id(id)

    # no row found?
    return if i == -1

    first = null
    last = null

    if @last_click != -1 && event.shiftKey
      first = @last_click
      last = i
    else
      first = last = @last_click = i
      @checked[i].on = !@checked[i].on

    isOn = @checked[first].on

    if !event.ctrlKey
      @set 0, @checked.length - 1, false
    @set first, last, isOn
    @update()

    event.stopPropagation()
    event.preventDefault()


  mouseover: (id, event) ->
    i = @get_row_by_id(id)

    return if i == -1

    if @last_click == -1
      @last_click = i

    return if !@dragging

    @set 0, @checked.length - 1, false
    first = @last_click
    last = i
    this_click = i
    @set first, last, true
    @update()


  undo: (redo) ->
    return if @count_selected() == 0

    list = []

    for entry in @checked
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
