// The following are instance methods and variables
var Note = Class.create({
  initialize: function(id, is_new, raw_body) {
    if (Note.debug) {
      console.debug("Note#initialize (id=%d)", id)
    }
    
    this.id = id
    this.is_new = is_new

    // Cache the elements
    this.elements = {
      box: $('note-box-' + this.id),
      corner: $('note-corner-' + this.id),
      body: $('note-body-' + this.id),
      image: $('image')
    }

    // Cache the dimensions
    this.fullsize = {
      left: this.elements.box.offsetLeft,
      top: this.elements.box.offsetTop,
      width: this.elements.box.clientWidth,
      height: this.elements.box.clientHeight
    }
    
    // Store the original values (in case the user clicks Cancel)
    this.old = {
      raw_body: raw_body,
      formatted_body: this.elements.body.innerHTML
    }
    for (p in this.fullsize) {
      this.old[p] = this.fullsize[p]
    }

    // Make the note translucent
    if (is_new) {
      this.elements.box.setOpacity(0.2)
    } else {
      this.elements.box.setOpacity(0.5)      
    }

    if (is_new && raw_body == '') {
      this.bodyfit = true
      this.elements.body.style.height = "100px"
    }

    // Attach the event listeners
    this.elements.box.observe("mousedown", this.dragStart.bindAsEventListener(this))
    this.elements.box.observe("mouseout", this.bodyHideTimer.bindAsEventListener(this))
    this.elements.box.observe("mouseover", this.bodyShow.bindAsEventListener(this))
    this.elements.corner.observe("mousedown", this.resizeStart.bindAsEventListener(this))
    this.elements.body.observe("mouseover", this.bodyShow.bindAsEventListener(this))
    this.elements.body.observe("mouseout", this.bodyHideTimer.bindAsEventListener(this))
    this.elements.body.observe("click", this.showEditBox.bindAsEventListener(this))

    this.adjustScale()
  },

  // Returns the raw text value of this note
  textValue: function() {
    if (Note.debug) {
      console.debug("Note#textValue (id=%d)", this.id)
    }
    
    return this.old.raw_body.strip()
  },

  // Removes the edit box
  hideEditBox: function(e) {
    if (Note.debug) {
      console.debug("Note#hideEditBox (id=%d)", this.id)
    }
      
    var editBox = $('edit-box')

    if (editBox != null) {
      var boxid = editBox.noteid

      $("edit-box").stopObserving()
      $("note-save-" + boxid).stopObserving()
      $("note-cancel-" + boxid).stopObserving()
      $("note-remove-" + boxid).stopObserving()
      $("note-history-" + boxid).stopObserving()
      $("edit-box").remove()
    }
  },

  // Shows the edit box
  showEditBox: function(e) {
    if (Note.debug) {
      console.debug("Note#showEditBox (id=%d)", this.id)
    }
    
    this.hideEditBox(e)

    var insertionPosition = Note.getInsertionPosition()
    var top = insertionPosition[0]
    var left = insertionPosition[1]
    var html = ""

    html += '<div id="edit-box" style="top: '+top+'px; left: '+left+'px; position: absolute; visibility: visible; z-index: 100; background: white; border: 1px solid black; padding: 12px;">'
    html += '<form onsubmit="return false;" style="padding: 0; margin: 0;">'
    html += '<textarea rows="7" id="edit-box-text" style="width: 350px; margin: 2px 2px 12px 2px;">' + this.textValue() + '</textarea>'
    html += '<input type="submit" value="Save" name="save" id="note-save-' + this.id + '">'
    html += '<input type="submit" value="Cancel" name="cancel" id="note-cancel-' + this.id + '">'
    html += '<input type="submit" value="Remove" name="remove" id="note-remove-' + this.id + '">'
    html += '<input type="submit" value="History" name="history" id="note-history-' + this.id + '">'
    html += '</form>'
    html += '</div>'

    $("note-container").insert({bottom: html})
    $('edit-box').noteid = this.id
    $("edit-box").observe("mousedown", this.editDragStart.bindAsEventListener(this))
    $("note-save-" + this.id).observe("click", this.save.bindAsEventListener(this))
    $("note-cancel-" + this.id).observe("click", this.cancel.bindAsEventListener(this))
    $("note-remove-" + this.id).observe("click", this.remove.bindAsEventListener(this))
    $("note-history-" + this.id).observe("click", this.history.bindAsEventListener(this))
    $("edit-box-text").focus()
  },

  // Shows the body text for the note
  bodyShow: function(e) {
    if (Note.debug) {
      console.debug("Note#bodyShow (id=%d)", this.id)
    }
    
    if (this.dragging) {
      return
    }

    if (this.hideTimer) {
      clearTimeout(this.hideTimer)
      this.hideTimer = null
    }

    if (Note.noteShowingBody == this) {
      return
    }
    
    if (Note.noteShowingBody) {
      Note.noteShowingBody.bodyHide()
    }
    
    Note.noteShowingBody = this

    if (Note.zindex >= 9) {
      /* don't use more than 10 layers (+1 for the body, which will always be above all notes) */
      Note.zindex = 0
      for (var i=0; i< Note.all.length; ++i) {
        Note.all[i].elements.box.style.zIndex = 0
      }
    }

    this.elements.box.style.zIndex = ++Note.zindex
    this.elements.body.style.zIndex = 10
    this.elements.body.style.top = 0 + "px"
    this.elements.body.style.left = 0 + "px"

    var dw = document.documentElement.scrollWidth
    this.elements.body.style.visibility = "hidden"
    this.elements.body.style.display = "block"
    if (!this.bodyfit) {
      this.elements.body.style.height = "auto"
      this.elements.body.style.minWidth = "140px"
      var w = null, h = null, lo = null, hi = null, x = null, last = null
      w = this.elements.body.offsetWidth
      h = this.elements.body.offsetHeight
      if (w/h < 1.6180339887) {
        /* for tall notes (lots of text), find more pleasant proportions */
        lo = 140, hi = 400
        do {
          last = w
          x = (lo+hi)/2
          this.elements.body.style.minWidth = x + "px"
          w = this.elements.body.offsetWidth
          h = this.elements.body.offsetHeight
          if (w/h < 1.6180339887) lo = x
          else hi = x
        } while ((lo < hi) && (w > last))
      } else if (this.elements.body.scrollWidth <= this.elements.body.clientWidth) {
        /* for short notes (often a single line), make the box no wider than necessary */  
        // scroll test necessary for Firefox
        lo = 20, hi = w
  
        do {
          x = (lo+hi)/2
          this.elements.body.style.minWidth = x + "px"
          if (this.elements.body.offsetHeight > h) lo = x
          else hi = x
        } while ((hi - lo) > 4)
        if (this.elements.body.offsetHeight > h)
          this.elements.body.style.minWidth = hi + "px"
      }
      
      if (Prototype.Browser.IE) {
        // IE7 adds scrollbars if the box is too small, obscuring the text
        if (this.elements.body.offsetHeight < 35) {
          this.elements.body.style.minHeight = "35px"
        }
        
        if (this.elements.body.offsetWidth < 47) {
          this.elements.body.style.minWidth = "47px"
        }
      }
      this.bodyfit = true
    }
    this.elements.body.style.top = (this.elements.box.offsetTop + this.elements.box.clientHeight + 5) + "px"
    // keep the box within the document's width
    var l = 0, e = this.elements.box
    do { l += e.offsetLeft } while (e = e.offsetParent)
    l += this.elements.body.offsetWidth + 10 - dw
    if (l > 0)
      this.elements.body.style.left = this.elements.box.offsetLeft - l + "px"
    else
      this.elements.body.style.left = this.elements.box.offsetLeft + "px"
    this.elements.body.style.visibility = "visible"
  },

  // Creates a timer that will hide the body text for the note
  bodyHideTimer: function(e) {
    if (Note.debug) {
      console.debug("Note#bodyHideTimer (id=%d)", this.id)
    }
    this.hideTimer = setTimeout(this.bodyHide.bindAsEventListener(this), 250)
  },

  // Hides the body text for the note
  bodyHide: function(e) {
    if (Note.debug) {
      console.debug("Note#bodyHide (id=%d)", this.id)
    }
    
    this.elements.body.hide()
    if (Note.noteShowingBody == this) {
      Note.noteShowingBody = null
    }
  },

  // Start dragging the note
  dragStart: function(e) {
    if (Note.debug) {
      console.debug("Note#dragStart (id=%d)", this.id)
    }
    
    document.observe("mousemove", this.drag.bindAsEventListener(this))
    document.observe("mouseup", this.dragStop.bindAsEventListener(this))
    document.observe("selectstart", function() {return false})

    this.cursorStartX = e.pointerX()
    this.cursorStartY = e.pointerY()
    this.boxStartX = this.elements.box.offsetLeft
    this.boxStartY = this.elements.box.offsetTop
    this.boundsX = new ClipRange(5, this.elements.image.clientWidth - this.elements.box.clientWidth - 5)
    this.boundsY = new ClipRange(5, this.elements.image.clientHeight - this.elements.box.clientHeight - 5)
    this.dragging = true
    this.bodyHide()
  },

  // Stop dragging the note
  dragStop: function(e) {
    if (Note.debug) {
      console.debug("Note#dragStop (id=%d)", this.id)
    }
    
    document.stopObserving()

    this.cursorStartX = null
    this.cursorStartY = null
    this.boxStartX = null
    this.boxStartY = null
    this.boundsX = null
    this.boundsY = null
    this.dragging = false

    this.bodyShow()
  },

  ratio: function() {
    return this.elements.image.width / this.elements.image.getAttribute("orig_width")
    // var ratio = this.elements.image.width / this.elements.image.getAttribute("orig_width")
    // if (this.elements.image.scale_factor != null)
      // ratio *= this.elements.image.scale_factor;
    // return ratio
  },

  // Scale the notes for when the image gets resized
  adjustScale: function() {
    if (Note.debug) {
      console.debug("Note#adjustScale (id=%d)", this.id)
    }
    
    var ratio = this.ratio()
    for (p in this.fullsize) {
      this.elements.box.style[p] = this.fullsize[p] * ratio + 'px'
    }
  },

  // Update the note's position as it gets dragged
  drag: function(e) {
    var left = this.boxStartX + e.pointerX() - this.cursorStartX
    var top = this.boxStartY + e.pointerY() - this.cursorStartY
    left = this.boundsX.clip(left)
    top = this.boundsY.clip(top)

    this.elements.box.style.left = left + 'px'
    this.elements.box.style.top = top + 'px'
    var ratio = this.ratio()
    this.fullsize.left = left / ratio
    this.fullsize.top = top / ratio

    e.stop()
  },
  
  // Start dragging the edit box
  editDragStart: function(e) {
    if (Note.debug) {
      console.debug("Note#editDragStart (id=%d)", this.id)
    }
    
    var node = e.element().nodeName
    if (node != 'FORM' && node != 'DIV') {
      return
    }

    document.observe("mousemove", this.editDrag.bindAsEventListener(this))
    document.observe("mouseup", this.editDragStop.bindAsEventListener(this))
    document.observe("selectstart", function() {return false})

    this.elements.editBox = $('edit-box');
    this.cursorStartX = e.pointerX()
    this.cursorStartY = e.pointerY()
    this.editStartX = this.elements.editBox.offsetLeft
    this.editStartY = this.elements.editBox.offsetTop
    this.dragging = true
  },

  // Stop dragging the edit box
  editDragStop: function(e) {
    if (Note.debug) {
      console.debug("Note#editDragStop (id=%d)", this.id)
    }
    document.stopObserving()

    this.cursorStartX = null
    this.cursorStartY = null
    this.editStartX = null
    this.editStartY = null
    this.dragging = false
  },

  // Update the edit box's position as it gets dragged
  editDrag: function(e) {
    var left = this.editStartX + e.pointerX() - this.cursorStartX
    var top = this.editStartY + e.pointerY() - this.cursorStartY

    this.elements.editBox.style.left = left + 'px'
    this.elements.editBox.style.top = top + 'px'

    e.stop()
  },

  // Start resizing the note
  resizeStart: function(e) {
    if (Note.debug) {
      console.debug("Note#resizeStart (id=%d)", this.id)
    }
    
    this.cursorStartX = e.pointerX()
    this.cursorStartY = e.pointerY()
    this.boxStartWidth = this.elements.box.clientWidth
    this.boxStartHeight = this.elements.box.clientHeight
    this.boxStartX = this.elements.box.offsetLeft
    this.boxStartY = this.elements.box.offsetTop
    this.boundsX = new ClipRange(10, this.elements.image.clientWidth - this.boxStartX - 5)
    this.boundsY = new ClipRange(10, this.elements.image.clientHeight - this.boxStartY - 5)
    this.dragging = true

    document.stopObserving()
    document.observe("mousemove", this.resize.bindAsEventListener(this))
    document.observe("mouseup", this.resizeStop.bindAsEventListener(this))
    
    e.stop()
    this.bodyHide()
  },

  // Stop resizing teh note
  resizeStop: function(e) {
    if (Note.debug) {
      console.debug("Note#resizeStop (id=%d)", this.id)
    }
    
    document.stopObserving()

    this.boxCursorStartX = null
    this.boxCursorStartY = null
    this.boxStartWidth = null
    this.boxStartHeight = null
    this.boxStartX = null
    this.boxStartY = null
    this.boundsX = null
    this.boundsY = null
    this.dragging = false

    e.stop()
  },

  // Update the note's dimensions as it gets resized
  resize: function(e) {
    var width = this.boxStartWidth + e.pointerX() - this.cursorStartX
    var height = this.boxStartHeight + e.pointerY() - this.cursorStartY
    width = this.boundsX.clip(width)
    height = this.boundsY.clip(height)

    this.elements.box.style.width = width + "px"
    this.elements.box.style.height = height + "px"
    var ratio = this.ratio()
    this.fullsize.width = width / ratio
    this.fullsize.height = height / ratio

    e.stop()
  },

  // Save the note to the database
  save: function(e) {
    if (Note.debug) {
      console.debug("Note#save (id=%d)", this.id)
    }
    
    var note = this
    for (p in this.fullsize) {
      this.old[p] = this.fullsize[p]
    }
    this.old.raw_body = $('edit-box-text').value
    this.old.formatted_body = this.textValue()
    // FIXME: this is not quite how the note will look (filtered elems, <tn>...). the user won't input a <script> that only damages him, but it might be nice to "preview" the <tn> here
    this.elements.body.update(this.textValue())

    this.hideEditBox(e)
    this.bodyHide()
    this.bodyfit = false

    var params = {
      "id": this.id,
      "note[x]": this.old.left,
      "note[y]": this.old.top,
      "note[width]": this.old.width,
      "note[height]": this.old.height,
      "note[body]": this.old.raw_body
    }
    
    if (this.is_new) {
      params["note[post_id]"] = Note.post_id
    }

    notice("Saving note...")

    new Ajax.Request('/note/update.json', {
      parameters: params,
      
      onComplete: function(resp) {
        var resp = resp.responseJSON
        
        if (resp.success) {
          notice("Note saved")
          var note = Note.find(resp.old_id)

          if (resp.old_id < 0) {
            note.is_new = false
            note.id = resp.new_id
            note.elements.box.id = 'note-box-' + note.id
            note.elements.body.id = 'note-body-' + note.id
            note.elements.corner.id = 'note-corner-' + note.id
          }
          note.elements.body.innerHTML = resp.formatted_body
          note.elements.box.setOpacity(0.5)
          note.elements.box.removeClassName('unsaved')
        } else {
          notice("Error: " + resp.reason)
          note.elements.box.addClassName('unsaved')
        }
      }
    })

    e.stop()
  },

  // Revert the note to the last saved state
  cancel: function(e) {
    if (Note.debug) {
      console.debug("Note#cancel (id=%d)", this.id)
    }
    
    this.hideEditBox(e)
    this.bodyHide()

    var ratio = this.ratio()
    for (p in this.fullsize) {
      this.fullsize[p] = this.old[p]
      this.elements.box.style[p] = this.fullsize[p] * ratio + 'px'
    }
    this.elements.body.innerHTML = this.old.formatted_body

    e.stop()
  },

  // Remove all references to the note from the page
  removeCleanup: function() {
    if (Note.debug) {
      console.debug("Note#removeCleanup (id=%d)", this.id)
    }
    
    this.elements.box.remove()
    this.elements.body.remove()

    var allTemp = []
    for (i=0; i<Note.all.length; ++i) {
      if (Note.all[i].id != this.id) {
        allTemp.push(Note.all[i])
      }
    }

    Note.all = allTemp
    Note.updateNoteCount()
  },

  // Removes a note from the database
  remove: function(e) {
    if (Note.debug) {
      console.debug("Note#remove (id=%d)", this.id)
    }
    
    this.hideEditBox(e)
    this.bodyHide()
    this_note = this

    if (this.is_new) {
      this.removeCleanup()
      notice("Note removed")

    } else {
      notice("Removing note...")

      new Ajax.Request('/note/update.json', {
        parameters: {
          "id": this.id,
          "note[is_active]": "0"
        },
        onComplete: function(resp) {
          var resp = resp.responseJSON
          
          if (resp.success) {
            notice("Note removed")
            this_note.removeCleanup()
          } else {
            notice("Error: " + resp.reason)
          }
        }
      })
    }

    e.stop()
  },

  // Redirect to the note's history
  history: function(e) {
    if (Note.debug) {
      console.debug("Note#history (id=%d)", this.id)
    }
    
    this.hideEditBox(e)

    if (this.is_new) {
      notice("This note has no history")
    } else {
      location.pathname = '/note/history/' + this.id
    }
    
    e.stop()
  }
})

// The following are class methods and variables
Object.extend(Note, {
  zindex: 0,
  counter: -1,
  all: [],
  display: true,
  debug: false,

  // Show all notes
  show: function() {
    if (Note.debug) {
      console.debug("Note.show")
    }
    
    $("note-container").show()
  },

  // Hide all notes
  hide: function() {
    if (Note.debug) {
      console.debug("Note.hide")
    }

    $("note-container").hide()
  },

  // Find a note instance based on the id number
  find: function(id) {
    if (Note.debug) {
      console.debug("Note.find")
    }
    
    for (var i=0; i<Note.all.size(); ++i) {
      if (Note.all[i].id == id) {
        return Note.all[i]
      }
    }

    return null
  },

  // Toggle the display of all notes
  toggle: function() {
    if (Note.debug) {
      console.debug("Note.toggle")
    }
    
    if (Note.display) {
      Note.hide()
      Note.display = false
    } else {
      Note.show()
      Note.display = true
    }
  },

  // Update the text displaying the number of notes a post has
  updateNoteCount: function() {
    if (Note.debug) {
      console.debug("Note.updateNoteCount")
    }
    
    if (Note.all.length > 0) {
      var label = ""

      if (Note.all.length == 1)
        label = "note"
      else
        label = "notes"

      $('note-count').innerHTML = "This post has <a href=\"/note/history?post_id=" + Note.post_id + "\">" + Note.all.length + " " + label + "</a>"
    } else {
      $('note-count').innerHTML = ""
    }
  },

  // Create a new note
  create: function() {
    if (Note.debug) {
      console.debug("Note.create")
    }

		Note.show()
    
    var insertion_position = Note.getInsertionPosition()
    var top = insertion_position[0]
    var left = insertion_position[1]
    var html = ''
    html += '<div class="note-box unsaved" style="width: 150px; height: 150px; '
    html += 'top: ' + top + 'px; '
    html += 'left: ' + left + 'px;" '
    html += 'id="note-box-' + Note.counter + '">'
    html += '<div class="note-corner" id="note-corner-' + Note.counter + '"></div>'
    html += '</div>'
    html += '<div class="note-body" title="Click to edit" id="note-body-' + Note.counter + '"></div>'
    $("note-container").insert({bottom: html})
    var note = new Note(Note.counter, true, "")
    Note.all.push(note)
    Note.counter -= 1
  },
  
  // Find a suitable position to insert new notes
  getInsertionPosition: function() {
    if (Note.debug) {
      console.debug("Note.getInsertionPosition")
    }
    
    // We want to show the edit box somewhere on the screen, but not outside the image.
    var scroll_x = $("image").cumulativeScrollOffset()[0]
    var scroll_y = $("image").cumulativeScrollOffset()[1]
    var image_left = $("image").positionedOffset()[0]
    var image_top = $("image").positionedOffset()[1]
    var image_right = image_left + $("image").width
    var image_bottom = image_top + $("image").height
    var left = 0
    var top = 0
    
    if (scroll_x > image_left) {
      left = scroll_x
    } else {
      left = image_left
    }
    
    if (scroll_y > image_top) {
      top = scroll_y
    } else {
      top = image_top + 20
    }
    
    if (top > image_bottom) {
      top = image_top + 20
    }
    
    return [top, left]
  }
})
