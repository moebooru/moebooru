export default class NotesManager
  constructor: ->
    @zindex = 0
    @counter = -1
    @all = []
    @display = true
    @debug = false

    jQuery(document).on 'click', '.js-notes-manager--toggle', @toggle


  show: =>
    if @debug
      console.debug '@show'
    $('note-container').show()
    return


  hide: =>
    if @debug
      console.debug '@hide'
    $('note-container').hide()
    return


  find: (id) =>
    if @debug
      console.debug '@find'

    for item in @all
      return item if item.id == id

    null


  toggle: (e) =>
    if @debug
      console.debug '@toggle'

    return if e.currentTarget.getAttribute('data-drag-element') == '1'

    @display = !@display

    if @display
      @show()
    else
      @hide()

    return


  updateNoteCount: =>
    if @debug
      console.debug '@updateNoteCount'
    if @all.length > 0
      label = ''
      if @all.length == 1
        label = 'note'
      else
        label = 'notes'
      $('note-count').innerHTML = 'This post has <a href="/note/history?post_id=' + @post_id + '">' + @all.length + ' ' + label + '</a>'
    else
      $('note-count').innerHTML = ''
    return


  create: =>
    if @debug
      console.debug '@create'
    @show()
    insertion_position = @getInsertionPosition()
    top = insertion_position[0]
    left = insertion_position[1]
    html = ''
    html += '<div class="note-box unsaved" style="width: 150px; height: 150px; '
    html += 'top: ' + top + 'px; '
    html += 'left: ' + left + 'px;" '
    html += 'id="note-box-' + @counter + '">'
    html += '<div class="note-corner" id="note-corner-' + @counter + '"></div>'
    html += '</div>'
    html += '<div class="note-body" title="Click to edit" id="note-body-' + @counter + '"></div>'
    $('note-container').insert bottom: html
    note = new Note(@counter, true, '')
    @all.push note
    @counter -= 1
    return


  getInsertionPosition: =>
    if @debug
      console.debug '@getInsertionPosition'
    # We want to show the edit box somewhere on the screen, but not outside the image.
    scroll_x = $('image').cumulativeScrollOffset()[0]
    scroll_y = $('image').cumulativeScrollOffset()[1]
    image_left = $('image').positionedOffset()[0]
    image_top = $('image').positionedOffset()[1]
    image_right = image_left + $('image').width
    image_bottom = image_top + $('image').height
    left = 0
    top = 0
    if scroll_x > image_left
      left = scroll_x
    else
      left = image_left
    if scroll_y > image_top
      top = scroll_y
    else
      top = image_top + 20
    if top > image_bottom
      top = image_top + 20
    [
      top
      left
    ]
