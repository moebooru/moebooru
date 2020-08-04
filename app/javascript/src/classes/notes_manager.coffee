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
      console.debug 'notesManager.show'
    $('note-container').show()
    return


  hide: =>
    if @debug
      console.debug 'notesManager.hide'
    $('note-container').hide()
    return


  find: (id) =>
    if @debug
      console.debug 'notesManager.find'

    for item in @all
      return item if item.id == id

    null


  toggle: (e) =>
    if @debug
      console.debug 'notesManager.toggle'

    return if e.currentTarget.getAttribute('data-drag-element') == '1'

    @display = !@display

    if @display
      @show()
    else
      @hide()

    return


  updateNoteCount: =>
    if @debug
      console.debug 'notesManager.updateNoteCount'
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
      console.debug 'notesManager.create'
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
      console.debug 'notesManager.getInsertionPosition'

    image = document.querySelector('.js-notes-manager--image')

    return [0, 0] unless image?

    rect = image.getBoundingClientRect()

    # Position the edit box 20px from top left of the image while making sure
    # it's also inside the screen. When either left or top side is outside
    # the screen, the visible part of it starts from its top (or left) rect
    # but on the other direction (hence negative sign).
    [-Math.min(rect.top, 0) + 20, -Math.min(rect.left, 0) + 20]
