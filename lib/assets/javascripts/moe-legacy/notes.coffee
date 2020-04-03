# The following are instance methods and variables
window.Note = Class.create(
  initialize: (id, is_new, raw_body) ->
    if Note.debug
      console.debug 'Note#initialize (id=%d)', id
    @id = id
    @is_new = is_new
    @document_observers = []
    # Cache the elements
    @elements =
      box: $('note-box-' + @id)
      corner: $('note-corner-' + @id)
      body: $('note-body-' + @id)
      image: $('image')
    # Cache the dimensions
    @fullsize =
      left: @elements.box.offsetLeft
      top: @elements.box.offsetTop
      width: @elements.box.clientWidth
      height: @elements.box.clientHeight
    # Store the original values (in case the user clicks Cancel)
    @old =
      raw_body: raw_body
      formatted_body: @elements.body.innerHTML
    for p of @fullsize
      @old[p] = @fullsize[p]
    # Make the note translucent
    if is_new
      @elements.box.setOpacity 0.2
    else
      @elements.box.setOpacity 0.5
    if is_new and raw_body == ''
      @bodyfit = true
      @elements.body.style.height = '100px'
    # Attach the event listeners
    @elements.box.observe 'mousedown', @dragStart.bindAsEventListener(this)
    @elements.box.observe 'mouseout', @bodyHideTimer.bindAsEventListener(this)
    @elements.box.observe 'mouseover', @bodyShow.bindAsEventListener(this)
    @elements.corner.observe 'mousedown', @resizeStart.bindAsEventListener(this)
    @elements.body.observe 'mouseover', @bodyShow.bindAsEventListener(this)
    @elements.body.observe 'mouseout', @bodyHideTimer.bindAsEventListener(this)
    @elements.body.observe 'click', @showEditBox.bindAsEventListener(this)
    @adjustScale()
    return
  textValue: ->
    if Note.debug
      console.debug 'Note#textValue (id=%d)', @id
    @old.raw_body.strip()
  hideEditBox: (e) ->
    if Note.debug
      console.debug 'Note#hideEditBox (id=%d)', @id
    editBox = $('edit-box')
    if editBox != null and editBox != undefined
      boxid = editBox.noteid
      $('edit-box').stopObserving()
      $('note-save-' + boxid).stopObserving()
      $('note-cancel-' + boxid).stopObserving()
      $('note-remove-' + boxid).stopObserving()
      $('note-history-' + boxid).stopObserving()
      $('edit-box').remove()
    return
  showEditBox: (e) ->
    if Note.debug
      console.debug 'Note#showEditBox (id=%d)', @id
    @hideEditBox e
    insertionPosition = Note.getInsertionPosition()
    top = insertionPosition[0]
    left = insertionPosition[1]
    html = ''
    html += '<div id="edit-box" style="top: ' + top + 'px; left: ' + left + 'px; position: absolute; visibility: visible; z-index: 100; background: white; border: 1px solid black; padding: 12px;">'
    html += '<form onsubmit="return false;" style="padding: 0; margin: 0;">'
    html += '<textarea rows="7" id="edit-box-text" style="width: 350px; margin: 2px 2px 12px 2px;">' + @textValue() + '</textarea>'
    html += '<input type="submit" value="Save" name="save" id="note-save-' + @id + '">'
    html += '<input type="submit" value="Cancel" name="cancel" id="note-cancel-' + @id + '">'
    html += '<input type="submit" value="Remove" name="remove" id="note-remove-' + @id + '">'
    html += '<input type="submit" value="History" name="history" id="note-history-' + @id + '">'
    html += '</form>'
    html += '</div>'
    $('note-container').insert bottom: html
    $('edit-box').noteid = @id
    $('edit-box').observe 'mousedown', @editDragStart.bindAsEventListener(this)
    $('note-save-' + @id).observe 'click', @save.bindAsEventListener(this)
    $('note-cancel-' + @id).observe 'click', @cancel.bindAsEventListener(this)
    $('note-remove-' + @id).observe 'click', @remove.bindAsEventListener(this)
    $('note-history-' + @id).observe 'click', @history.bindAsEventListener(this)
    $('edit-box-text').focus()
    return
  bodyShow: (e) ->
    if Note.debug
      console.debug 'Note#bodyShow (id=%d)', @id
    if @dragging
      return
    if @hideTimer
      clearTimeout @hideTimer
      @hideTimer = null
    if Note.noteShowingBody == this
      return
    if Note.noteShowingBody
      Note.noteShowingBody.bodyHide()
    Note.noteShowingBody = this
    if Note.zindex >= 9

      ### don't use more than 10 layers (+1 for the body, which will always be above all notes) ###

      Note.zindex = 0
      i = 0
      while i < Note.all.length
        Note.all[i].elements.box.style.zIndex = 0
        ++i
    @elements.box.style.zIndex = ++Note.zindex
    @elements.body.style.zIndex = 10
    @elements.body.style.top = 0 + 'px'
    @elements.body.style.left = 0 + 'px'
    dw = document.documentElement.scrollWidth
    @elements.body.style.visibility = 'hidden'
    @elements.body.style.display = 'block'
    if !@bodyfit
      @elements.body.style.height = 'auto'
      @elements.body.style.minWidth = '140px'
      w = null
      h = null
      lo = null
      hi = null
      x = null
      last = null
      w = @elements.body.offsetWidth
      h = @elements.body.offsetHeight
      if w / h < 1.6180339887

        ### for tall notes (lots of text), find more pleasant proportions ###

        lo = 140
        hi = 400
        loop
          last = w
          x = (lo + hi) / 2
          @elements.body.style.minWidth = x + 'px'
          w = @elements.body.offsetWidth
          h = @elements.body.offsetHeight
          if w / h < 1.6180339887
            lo = x
          else
            hi = x
          unless lo < hi and w > last
            break
      else if @elements.body.scrollWidth <= @elements.body.clientWidth

        ### for short notes (often a single line), make the box no wider than necessary ###

        # scroll test necessary for Firefox
        lo = 20
        hi = w
        loop
          x = (lo + hi) / 2
          @elements.body.style.minWidth = x + 'px'
          if @elements.body.offsetHeight > h
            lo = x
          else
            hi = x
          unless hi - lo > 4
            break
        if @elements.body.offsetHeight > h
          @elements.body.style.minWidth = hi + 'px'
      if Prototype.Browser.IE
        # IE7 adds scrollbars if the box is too small, obscuring the text
        if @elements.body.offsetHeight < 35
          @elements.body.style.minHeight = '35px'
        if @elements.body.offsetWidth < 47
          @elements.body.style.minWidth = '47px'
      @bodyfit = true
    @elements.body.style.top = @elements.box.offsetTop + @elements.box.clientHeight + 5 + 'px'
    # keep the box within the document's width
    l = 0
    e = @elements.box
    l += e.offsetLeft
    while e = e.offsetParent
      l += e.offsetLeft
    l += @elements.body.offsetWidth + 10 - dw
    if l > 0
      @elements.body.style.left = @elements.box.offsetLeft - l + 'px'
    else
      @elements.body.style.left = @elements.box.offsetLeft + 'px'
    @elements.body.style.visibility = 'visible'
    return
  bodyHideTimer: (e) ->
    if Note.debug
      console.debug 'Note#bodyHideTimer (id=%d)', @id
    @hideTimer = setTimeout(@bodyHide.bindAsEventListener(this), 250)
    return
  bodyHide: (e) ->
    if Note.debug
      console.debug 'Note#bodyHide (id=%d)', @id
    @elements.body.hide()
    if Note.noteShowingBody == this
      Note.noteShowingBody = null
    return
  addDocumentObserver: (name, func) ->
    document.observe name, func
    @document_observers.push [
      name
      func
    ]
    return
  clearDocumentObservers: (name, handler) ->
    i = 0
    while i < @document_observers.length
      observer = @document_observers[i]
      document.stopObserving observer[0], observer[1]
      ++i
    @document_observers = []
    return
  dragStart: (e) ->
    if Note.debug
      console.debug 'Note#dragStart (id=%d)', @id
    @addDocumentObserver 'mousemove', @drag.bindAsEventListener(this)
    @addDocumentObserver 'mouseup', @dragStop.bindAsEventListener(this)
    @addDocumentObserver 'selectstart', ->
      false
    @cursorStartX = e.pointerX()
    @cursorStartY = e.pointerY()
    @boxStartX = @elements.box.offsetLeft
    @boxStartY = @elements.box.offsetTop
    @boundsX = new ClipRange(5, @elements.image.clientWidth - (@elements.box.clientWidth) - 5)
    @boundsY = new ClipRange(5, @elements.image.clientHeight - (@elements.box.clientHeight) - 5)
    @dragging = true
    @bodyHide()
    return
  dragStop: (e) ->
    if Note.debug
      console.debug 'Note#dragStop (id=%d)', @id
    @clearDocumentObservers()
    @cursorStartX = null
    @cursorStartY = null
    @boxStartX = null
    @boxStartY = null
    @boundsX = null
    @boundsY = null
    @dragging = false
    @bodyShow()
    return
  ratio: ->
    @elements.image.width / @elements.image.getAttribute('large_width')
    # var ratio = this.elements.image.width / this.elements.image.getAttribute("large_width")
    # if (this.elements.image.scale_factor != null)
    # ratio *= this.elements.image.scale_factor;
    # return ratio
  adjustScale: ->
    if Note.debug
      console.debug 'Note#adjustScale (id=%d)', @id
    ratio = @ratio()
    for p of @fullsize
      @elements.box.style[p] = @fullsize[p] * ratio + 'px'
    return
  drag: (e) ->
    left = @boxStartX + e.pointerX() - (@cursorStartX)
    top = @boxStartY + e.pointerY() - (@cursorStartY)
    left = @boundsX.clip(left)
    top = @boundsY.clip(top)
    @elements.box.style.left = left + 'px'
    @elements.box.style.top = top + 'px'
    ratio = @ratio()
    @fullsize.left = left / ratio
    @fullsize.top = top / ratio
    e.stop()
    return
  editDragStart: (e) ->
    if Note.debug
      console.debug 'Note#editDragStart (id=%d)', @id
    node = e.element().nodeName
    if node != 'FORM' and node != 'DIV'
      return
    @addDocumentObserver 'mousemove', @editDrag.bindAsEventListener(this)
    @addDocumentObserver 'mouseup', @editDragStop.bindAsEventListener(this)
    @addDocumentObserver 'selectstart', ->
      false
    @elements.editBox = $('edit-box')
    @cursorStartX = e.pointerX()
    @cursorStartY = e.pointerY()
    @editStartX = @elements.editBox.offsetLeft
    @editStartY = @elements.editBox.offsetTop
    @dragging = true
    return
  editDragStop: (e) ->
    if Note.debug
      console.debug 'Note#editDragStop (id=%d)', @id
    @clearDocumentObservers()
    @cursorStartX = null
    @cursorStartY = null
    @editStartX = null
    @editStartY = null
    @dragging = false
    return
  editDrag: (e) ->
    left = @editStartX + e.pointerX() - (@cursorStartX)
    top = @editStartY + e.pointerY() - (@cursorStartY)
    @elements.editBox.style.left = left + 'px'
    @elements.editBox.style.top = top + 'px'
    e.stop()
    return
  resizeStart: (e) ->
    if Note.debug
      console.debug 'Note#resizeStart (id=%d)', @id
    @cursorStartX = e.pointerX()
    @cursorStartY = e.pointerY()
    @boxStartWidth = @elements.box.clientWidth
    @boxStartHeight = @elements.box.clientHeight
    @boxStartX = @elements.box.offsetLeft
    @boxStartY = @elements.box.offsetTop
    @boundsX = new ClipRange(10, @elements.image.clientWidth - (@boxStartX) - 5)
    @boundsY = new ClipRange(10, @elements.image.clientHeight - (@boxStartY) - 5)
    @dragging = true
    @clearDocumentObservers()
    @addDocumentObserver 'mousemove', @resize.bindAsEventListener(this)
    @addDocumentObserver 'mouseup', @resizeStop.bindAsEventListener(this)
    e.stop()
    @bodyHide()
    return
  resizeStop: (e) ->
    if Note.debug
      console.debug 'Note#resizeStop (id=%d)', @id
    @clearDocumentObservers()
    @boxCursorStartX = null
    @boxCursorStartY = null
    @boxStartWidth = null
    @boxStartHeight = null
    @boxStartX = null
    @boxStartY = null
    @boundsX = null
    @boundsY = null
    @dragging = false
    e.stop()
    return
  resize: (e) ->
    width = @boxStartWidth + e.pointerX() - (@cursorStartX)
    height = @boxStartHeight + e.pointerY() - (@cursorStartY)
    width = @boundsX.clip(width)
    height = @boundsY.clip(height)
    @elements.box.style.width = width + 'px'
    @elements.box.style.height = height + 'px'
    ratio = @ratio()
    @fullsize.width = width / ratio
    @fullsize.height = height / ratio
    e.stop()
    return
  save: (e) ->
    if Note.debug
      console.debug 'Note#save (id=%d)', @id
    note = this
    for p of @fullsize
      @old[p] = @fullsize[p]
    @old.raw_body = $('edit-box-text').value
    @old.formatted_body = @textValue()
    # FIXME: this is not quite how the note will look (filtered elems, <tn>...). the user won't input a <script> that only damages him, but it might be nice to "preview" the <tn> here
    @elements.body.update @textValue()
    @hideEditBox e
    @bodyHide()
    @bodyfit = false
    params = 
      'id': @id
      'note[x]': @old.left
      'note[y]': @old.top
      'note[width]': @old.width
      'note[height]': @old.height
      'note[body]': @old.raw_body
    if @is_new
      params['note[post_id]'] = Note.post_id
    notice 'Saving note...'
    new (Ajax.Request)('/note/update.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters: params
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          notice 'Note saved'
          note = Note.find(resp.old_id)
          if resp.old_id < 0
            note.is_new = false
            note.id = resp.new_id
            note.elements.box.id = 'note-box-' + note.id
            note.elements.body.id = 'note-body-' + note.id
            note.elements.corner.id = 'note-corner-' + note.id
          note.elements.body.innerHTML = resp.formatted_body
          note.elements.box.setOpacity 0.5
          note.elements.box.removeClassName 'unsaved'
        else
          notice 'Error: ' + resp.reason
          note.elements.box.addClassName 'unsaved'
        return
)
    e.stop()
    return
  cancel: (e) ->
    if Note.debug
      console.debug 'Note#cancel (id=%d)', @id
    @hideEditBox e
    @bodyHide()
    ratio = @ratio()
    for p of @fullsize
      @fullsize[p] = @old[p]
      @elements.box.style[p] = @fullsize[p] * ratio + 'px'
    @elements.body.innerHTML = @old.formatted_body
    e.stop()
    return
  removeCleanup: ->
    if Note.debug
      console.debug 'Note#removeCleanup (id=%d)', @id
    @elements.box.remove()
    @elements.body.remove()
    allTemp = []
    i = 0
    while i < Note.all.length
      if Note.all[i].id != @id
        allTemp.push Note.all[i]
      ++i
    Note.all = allTemp
    Note.updateNoteCount()
    return
  remove: (e) ->
    if Note.debug
      console.debug 'Note#remove (id=%d)', @id
    @hideEditBox e
    @bodyHide()
    this_note = this
    if @is_new
      @removeCleanup()
      notice 'Note removed'
    else
      notice 'Removing note...'
      new (Ajax.Request)('/note/update.json',
        requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
        parameters:
          'id': @id
          'note[is_active]': '0'
        onComplete: (resp) ->
          resp = resp.responseJSON
          if resp.success
            notice 'Note removed'
            this_note.removeCleanup()
          else
            notice 'Error: ' + resp.reason
          return
)
    e.stop()
    return
  history: (e) ->
    if Note.debug
      console.debug 'Note#history (id=%d)', @id
    @hideEditBox e
    if @is_new
      notice 'This note has no history'
    else
      location.href = '/history?search=notes:' + @id
    e.stop()
    return
)
# The following are class methods and variables
Object.extend Note,
  zindex: 0
  counter: -1
  all: []
  display: true
  debug: false
  show: ->
    if Note.debug
      console.debug 'Note.show'
    $('note-container').show()
    return
  hide: ->
    if Note.debug
      console.debug 'Note.hide'
    $('note-container').hide()
    return
  find: (id) ->
    if Note.debug
      console.debug 'Note.find'
    i = 0
    while i < Note.all.size()
      if Note.all[i].id == id
        return Note.all[i]
      ++i
    null
  toggle: ->
    if Note.debug
      console.debug 'Note.toggle'
    if Note.display
      Note.hide()
      Note.display = false
    else
      Note.show()
      Note.display = true
    return
  updateNoteCount: ->
    if Note.debug
      console.debug 'Note.updateNoteCount'
    if Note.all.length > 0
      label = ''
      if Note.all.length == 1
        label = 'note'
      else
        label = 'notes'
      $('note-count').innerHTML = 'This post has <a href="/note/history?post_id=' + Note.post_id + '">' + Note.all.length + ' ' + label + '</a>'
    else
      $('note-count').innerHTML = ''
    return
  create: ->
    if Note.debug
      console.debug 'Note.create'
    Note.show()
    insertion_position = Note.getInsertionPosition()
    top = insertion_position[0]
    left = insertion_position[1]
    html = ''
    html += '<div class="note-box unsaved" style="width: 150px; height: 150px; '
    html += 'top: ' + top + 'px; '
    html += 'left: ' + left + 'px;" '
    html += 'id="note-box-' + Note.counter + '">'
    html += '<div class="note-corner" id="note-corner-' + Note.counter + '"></div>'
    html += '</div>'
    html += '<div class="note-body" title="Click to edit" id="note-body-' + Note.counter + '"></div>'
    $('note-container').insert bottom: html
    note = new Note(Note.counter, true, '')
    Note.all.push note
    Note.counter -= 1
    return
  getInsertionPosition: ->
    if Note.debug
      console.debug 'Note.getInsertionPosition'
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
