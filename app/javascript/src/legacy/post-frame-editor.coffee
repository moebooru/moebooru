create_drag_box = (div) ->

  create_handle = (cursor, style) ->
    handle = $(document.createElement('div'))
    handle.style.position = 'absolute'
    handle.className = 'frame-box-handle ' + cursor
    handle.frame_drag_cursor = cursor
    handle.style.pointerEvents = 'all'
    div.appendChild handle
    for s of style
      handle.style[s] = style[s]
    handle

  ### Create the corner handles after the edge handles, so they're on top. ###

  create_handle 'n-resize',
    top: '-5px'
    width: '100%'
    height: '10px'
  create_handle 's-resize',
    bottom: '-5px'
    width: '100%'
    height: '10px'
  create_handle 'w-resize',
    left: '-5px'
    height: '100%'
    width: '10px'
  create_handle 'e-resize',
    right: '-5px'
    height: '100%'
    width: '10px'
  create_handle 'nw-resize',
    top: '-5px'
    left: '-5px'
    height: '10px'
    width: '10px'
  create_handle 'ne-resize',
    top: '-5px'
    right: '-5px'
    height: '10px'
    width: '10px'
  create_handle 'sw-resize',
    bottom: '-5px'
    left: '-5px'
    height: '10px'
    width: '10px'
  create_handle 'se-resize',
    bottom: '-5px'
    right: '-5px'
    height: '10px'
    width: '10px'
  return

apply_drag = (dragging_mode, x, y, image_dimensions, box) ->
  move_modes = 
    'move':
      left: +1
      top: +1
      bottom: +1
      right: +1
    'n-resize': top: +1
    's-resize': bottom: +1
    'w-resize': left: +1
    'e-resize': right: +1
    'nw-resize':
      top: +1
      left: +1
    'ne-resize':
      top: +1
      right: +1
    'sw-resize':
      bottom: +1
      left: +1
    'se-resize':
      bottom: +1
      right: +1
  mode = move_modes[dragging_mode]
  result = 
    left: box.left
    top: box.top
    width: box.width
    height: box.height
  right = result.left + result.width
  bottom = result.top + result.height
  if dragging_mode == 'move'

    ### In move mode, clamp the movement.  In other modes, clip the size below. ###

    x = clamp(x, -result.left, image_dimensions.width - right)
    y = clamp(y, -result.top, image_dimensions.height - bottom)

  ### Apply the drag. ###

  if mode.top?
    result.top += y * mode.top
  if mode.left?
    result.left += x * mode.left
  if mode.right?
    right += x * mode.right
  if mode.bottom?
    bottom += y * mode.bottom
  if dragging_mode != 'move'

    ### Only clamp the dimensions that were modified. ###

    if mode.left?
      result.left = clamp(result.left, 0, right - 1)
    if mode.top?
      result.top = clamp(result.top, 0, bottom - 1)
    if mode.bottom?
      bottom = clamp(bottom, result.top + 1, image_dimensions.height)
    if mode.right?
      right = clamp(right, result.left + 1, image_dimensions.width)
  result.width = right - (result.left)
  result.height = bottom - (result.top)
  result

###
# Given a frame, its post and an image, return the frame's rectangle scaled to
# the size of the image.
###

frame_dimensions_to_image = (frame, image, post) ->
  result = 
    top: frame.source_top
    left: frame.source_left
    width: frame.source_width
    height: frame.source_height
  result.left *= image.width / post.width
  result.top *= image.height / post.height
  result.width *= image.width / post.width
  result.height *= image.height / post.height
  result.top = Math.round(result.top)
  result.left = Math.round(result.left)
  result.width = Math.round(result.width)
  result.height = Math.round(result.height)
  result

###
# Convert dimensions scaled to an image back to the source resolution.
###

frame_dimensions_from_image = (frame, image, post) ->
  result = 
    source_top: frame.top
    source_left: frame.left
    source_width: frame.width
    source_height: frame.height

  ### Scale the coordinates back into the source resolution. ###

  result.source_top /= image.height / post.height
  result.source_left /= image.width / post.width
  result.source_height /= image.height / post.height
  result.source_width /= image.width / post.width
  result.source_top = Math.round(result.source_top)
  result.source_left = Math.round(result.source_left)
  result.source_width = Math.round(result.source_width)
  result.source_height = Math.round(result.source_height)
  result

window.FrameEditor = (container, image_container, popup_container, options) ->
  @container = container
  @popup_container = popup_container
  @image_container = image_container
  @options = options
  @show_corner_drag = true
  @image_frames = []

  ### Event handlers which are set only while the tag editor is open: ###

  @open_handlers = []

  ### Set up the four parts of the corner dragger. ###

  popup_parts = [
    '.frame-editor-nw'
    '.frame-editor-ne'
    '.frame-editor-sw'
    '.frame-editor-se'
  ]
  @corner_draggers = []
  div = undefined
  i = 0
  while i < popup_parts.length
    part = popup_parts[i]
    div = @popup_container.down(part)
    corner_dragger = new CornerDragger(div, part, onUpdate: (->
      @update_frame_in_list @editing_frame
      @update_image_frame @editing_frame
      return
    ).bind(this))
    @corner_draggers.push corner_dragger
    ++i

  ### Create the main frame.  This sits on top of the image, receives mouse events and
  # holds the individual frames. 
  ###

  div = $(document.createElement('div'))
  div.style.position = 'absolute'
  div.style.left = '0'
  div.style.top = '0'
  div.className = 'frame-editor-main-frame'
  @image_container.appendChild div
  @main_frame = div
  @main_frame.hide()

  ### Frame editor buttons: ###

  @container.down('.frame-editor-add').on 'click', ((e) ->
    e.stop()
    @add_frame()
    return
  ).bindAsEventListener(this)

  ### Buttons in the frame table: ###

  @container.on 'click', '.frame-label', ((e, element) ->
    e.stop()
    frame_idx = element.up('.frame-row').frame_idx
    @focus frame_idx
    return
  ).bind(this)
  @container.on 'click', '.frame-delete', ((e, element) ->
    e.stop()
    frame_idx = element.up('.frame-row').frame_idx
    @delete_frame frame_idx
    return
  ).bind(this)
  @container.on 'click', '.frame-up', ((e, element) ->
    e.stop()
    frame_idx = element.up('.frame-row').frame_idx
    @move_frame frame_idx, frame_idx - 1
    return
  ).bind(this)
  @container.on 'click', '.frame-down', ((e, element) ->
    e.stop()
    frame_idx = element.up('.frame-row').frame_idx
    @move_frame frame_idx, frame_idx + 1
    return
  ).bind(this)
  @container.down('table').on 'change', ((e) ->
    @form_data_changed()
    return
  ).bind(this)
  return

FrameEditor::move_frame = (frame_idx, frame_idx_target) ->
  post = Post.posts.get(@post_id)
  frame_idx_target = Math.max(frame_idx_target, 0)
  frame_idx_target = Math.min(frame_idx_target, post.frames_pending.length - 1)
  if frame_idx == frame_idx_target
    return
  frame = post.frames_pending[frame_idx]
  post.frames_pending.splice frame_idx, 1
  post.frames_pending.splice frame_idx_target, 0, frame
  @repopulate_table()

  ### Reset the focus.  If the item that was moved was focused, focus on it in
  # its new position. 
  ###

  editing_frame = if @editing_frame == frame_idx then frame_idx_target else @editing_frame
  @editing_frame = null
  @focus editing_frame
  return

FrameEditor::form_data_changed = ->
  post = Post.posts.get(@post_id)
  i = 0
  while i < post.frames_pending.length
    @update_frame_from_list i
    ++i
  @update()
  return

FrameEditor::set_drag_to_create = (enable) ->
  @drag_to_create = enable
  return

FrameEditor::update_show_corner_drag = ->
  shown = @post_id? and @editing_frame? and @show_corner_drag
  if Prototype.Browser.WebKit

    ### Work around a WebKit (maybe just a Chrome) issue.  Images are downloaded immediately, but
    # they're only decompressed the first time they're actually painted on screen.  This happens
    # late, after all style is applied: hiding with display: none, visibility: hidden or even
    # opacity: 0 causes the image to not be decoded until it's displayed, which causes a huge
    # UI hitch the first time the user drags a box.  Work around this by setting opacity very
    # small; it'll trick it into decoding the image, but it'll clip to 0 when rendered. 
    ###

    if shown
      @popup_container.style.opacity = 1
      @popup_container.style.pointerEvents = ''
      @popup_container.style.position = 'static'
    else
      @popup_container.style.opacity = 0.001

      ### Make sure the invisible element doesn't interfere with the page; disable pointer-events
      # so it doesn't receive clicks, and set it to absolute so it doesn't affect the size of its
      # containing box. 
      ###

      @popup_container.style.pointerEvents = 'none'
      @popup_container.style.position = 'absolute'
      @popup_container.style.top = '0px'
      @popup_container.style.right = '0px'
    @popup_container.show()
  else
    @popup_container.show shown
  i = 0
  while i < @corner_draggers.length
    @corner_draggers[i].update()
    ++i
  return

FrameEditor::set_show_corner_drag = (enable) ->
  @show_corner_drag = enable
  @update_show_corner_drag()
  return

FrameEditor::set_image_dimensions = (width, height) ->
  editing_frame = @editing_frame
  post_id = @post_id
  @close()
  @image_dimensions =
    width: width
    height: height
  @main_frame.style.width = @image_dimensions.width + 'px'
  @main_frame.style.height = @image_dimensions.height + 'px'
  if post_id?
    @open post_id
    @focus editing_frame
  return

###
# Like document.elementFromPoint, but returns an array of all elements at the given point.
# If a top element is specified, stop if it's reached without including it in the list.
#
###

elementArrayFromPoint = (x, y, top) ->
  elements = []
  loop
    element = document.elementFromPoint(x, y)
    if element == @main_frame or element == document.documentElement
      break
    element.original_display = element.style.display
    element.style.display = 'none'
    elements.push element

  ### Restore the elements we just hid. ###

  elements.each (e) ->
    e.style.display = e.original_display
    e.original_display = null
    return
  elements

FrameEditor::is_opened = ->
  @post_id?

### Open the frame editor if it isn't already, and focus on the specified frame. ###

FrameEditor::open = (post_id) ->
  if !@image_dimensions?
    throw 'Must call set_image_dimensions before open'
  if @post_id?
    return
  @post_id = post_id
  @editing_frame = null
  @dragging_item = null
  @container.show()
  @main_frame.show()
  @update_show_corner_drag()
  post = Post.posts.get(@post_id)

  ### Tell the corner draggers which post we're working on now, so they'll start
  # loading the JPEG version immediately if necessary.  Otherwise, we'll start
  # loading it the first time we focus a frame, which will hitch the editor for
  # a while in Chrome. 
  ###

  i = 0
  while i < @corner_draggers.length
    @corner_draggers[i].set_post_id @post_id
    ++i
  @open_handlers.push document.on('keydown', ((e) ->
    if e.keyCode == Event.KEY_ESC
      @discard()
    return
  ).bindAsEventListener(this))

  ### If we havn't done so already, make a backup of this post's frames.  We'll restore
  # from this later if the user cancels the edit. 
  ###

  @original_frames = Object.toJSON(post.frames_pending)
  @repopulate_table()
  @create_dragger()
  if post.frames_pending.length > 0
    @focus 0
  @update()
  return

FrameEditor::create_dragger = ->
  if @dragger
    @dragger.destroy()
  @dragger = new DragElement(@main_frame,
    ondown: ((e) ->
      post = Post.posts.get(@post_id)

      ###
      # Figure out which element(s) we're clicking on.  The click may lie on a spot
      # where multiple frames overlap; make a list.
      #
      # Temporarily enable pointerEvents on the frames, so elementFromPoint will
      # resolve them.
      ###

      @image_frames.each (frame) ->
        frame.style.pointerEvents = 'all'
        return
      clicked_elements = elementArrayFromPoint(e.x, e.y, @main_frame)
      @image_frames.each (frame) ->
        frame.style.pointerEvents = 'none'
        return

      ### If we clicked on a handle, prefer it over frame bodies at the same spot. ###

      element = null
      clicked_elements.each ((e) ->

        ### If a handle was clicked, always prefer it.  Use the first handle we find,
        # so we prefer the corner handles (which are always on top) to edge handles. 
        ###

        if (!element?) and e.hasClassName('frame-box-handle')
          element = e
        return
      ).bind(this)

      ### If a handle wasn't clicked, prefer the frame that's currently focused. ###

      if !element?
        clicked_elements.each ((e) ->
          if !e.hasClassName('frame-editor-frame-box')
            e = e.up('.frame-editor-frame-box')
          if @image_frames.indexOf(e) == @editing_frame
            element = e
          return
        ).bind(this)

      ### Otherwise, just use the first item that was found. ###

      if !element?
        element = clicked_elements[0]

      ### If a handle was clicked on, find the frame element that contains it. ###

      frame_element = element
      if !frame_element.hasClassName('frame-editor-frame-box')
        frame_element = frame_element.up('.frame-editor-frame-box')

      ### If we didn't click on a frame box at all, create a new one. ###

      if !frame_element?
        if !@drag_to_create
          return
        @dragging_new = true
      else
        @dragging_new = false

      ### If the element we actually clicked on was one of the edge handles, set the drag
      # mode based on which one was clicked. 
      ###

      if element.hasClassName('frame-box-handle')
        @dragging_mode = element.frame_drag_cursor
      else
        @dragging_mode = 'move'
      if frame_element and frame_element.hasClassName('frame-editor-frame-box')
        frame_idx = @image_frames.indexOf(frame_element)
        @dragging_idx = frame_idx
        frame = post.frames_pending[@dragging_idx]
        @dragging_anchor = frame_dimensions_to_image(frame, @image_dimensions, post)
      @focus @dragging_idx

      ### If we're dragging a handle, override the drag class so the pointer will
      # use the handle pointer instead of the drag pointer. 
      ###

      @dragger.overriden_drag_class = if @dragging_mode == 'move' then null else @dragging_mode
      @dragger.options.snap_pixels = if @dragging_new then 10 else 0

      ### Stop propagation of the event, so any other draggers in the chain don't start.  In
      # particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
      # Only do this if we're actually dragging, not if we aborted due to this.drag_to_create. 
      ###

      e.latest_event.stopPropagation()
      return
    ).bind(this)
    onup: ((e) ->
      @dragging_idx = null
      @dragging_anchor = null
      return
    ).bind(this)
    ondrag: ((e) ->
      post = Post.posts.get(@post_id)
      dims = undefined
      source_dims = undefined
      if @dragging_new

        ### Pick a dragging mode based on which way we were dragged.  This is a
        # little funny; we should probably be able to drag freely, not be fixed
        # to the first direction we drag. 
        ###

        if e.aX > 0 and e.aY > 0
          @dragging_mode = 'se-resize'
        else if e.aX > 0 and e.aY < 0
          @dragging_mode = 'ne-resize'
        else if e.aX < 0 and e.aY > 0
          @dragging_mode = 'sw-resize'
        else if e.aX < 0 and e.aY < 0
          @dragging_mode = 'nw-resize'
        else
          return
        @dragging_new = false

        ### Create a new, empty frame.  When we get to the regular drag path below we'll
        # give it its real size, based on how far we've dragged so far. 
        ###

        frame_offset = @main_frame.cumulativeOffset()
        dims =
          left: e.dragger.anchor_x - (frame_offset.left)
          top: e.dragger.anchor_y - (frame_offset.top)
          height: 0
          width: 0
        @dragging_anchor = dims
        source_dims = frame_dimensions_from_image(dims, @image_dimensions, post)
        @dragging_idx = @add_frame(source_dims)
        post.frames_pending[@editing_frame] = source_dims
      if !@dragging_idx?
        return
      dims = apply_drag(@dragging_mode, e.aX, e.aY, @image_dimensions, @dragging_anchor)

      ### Scale the changed dimensions back to the source resolution and apply them
      # to the frame. 
      ###

      source_dims = frame_dimensions_from_image(dims, @image_dimensions, post)
      post.frames_pending[@editing_frame] = source_dims
      @update_frame_in_list @editing_frame
      @update_image_frame @editing_frame
      return
    ).bind(this))
  return

FrameEditor::repopulate_table = ->
  post = Post.posts.get(@post_id)

  ### Clear the table. ###

  tbody = @container.down('.frame-list').down('TBODY')
  while tbody.firstChild
    tbody.removeChild tbody.firstChild

  ### Clear the image frames. ###

  @image_frames.each ((f) ->
    f.parentNode.removeChild f
    return
  ).bind(this)
  @image_frames = []
  i = 0
  while i < post.frames_pending.length
    @add_frame_to_list i
    @create_image_frame()
    @update_image_frame i
    ++i
  return

FrameEditor::update = ->
  @update_show_corner_drag()
  if !@image_dimensions?
    return
  post = Post.posts.get(@post_id)
  if post?
    i = 0
    while i < post.frames_pending.length
      @update_image_frame i
      ++i
  return

### If the frame editor is open, discard changes and close it. ###

FrameEditor::discard = ->
  if !@post_id?
    return

  ### Save revert_to, and close the editor before reverting, to make sure closing
  # the editor doesn't change anything. 
  ###

  revert_to = @original_frames
  post_id = @post_id
  @close()

  ### Revert changes. ###

  post = Post.posts.get(post_id)
  post.frames_pending = revert_to.evalJSON()
  return

### Get the frames specifier for the post's frames. ###

FrameEditor::get_current_frames_spec = ->
  post = Post.posts.get(@post_id)
  frame = post.frames_pending
  frame_specs = []
  post.frames_pending.each ((frame) ->
    s = frame.source_left + 'x' + frame.source_top + ',' + frame.source_width + 'x' + frame.source_height
    frame_specs.push s
    return
  ).bind(this)
  frame_specs.join ';'

### Return true if the frames have been changed. ###

FrameEditor::changed = ->
  post = Post.posts.get(@post_id)
  spec = @get_current_frames_spec()
  spec != post.frames_pending_string

### Save changes to the post, if any.  If not null, call finished on completion. ###

FrameEditor::save = (finished) ->
  if !@post_id?
    if finished
      finished()
    return

  ### Save the current post_id, so it's preserved when the AJAX completion function
  # below is run. 
  ###

  post_id = @post_id
  post = Post.posts.get(post_id)
  frame = post.frames_pending
  spec = @get_current_frames_spec()
  if spec == post.frames_pending_string
    if finished
      finished()
    return
  Post.update_batch [ {
    id: post_id
    frames_pending_string: spec
  } ], ((posts) ->
    if @post_id == post_id

      ### The registered post has been changed, and we're still displaying it.  Grab the
      # new version, and updated original_frames so we no longer consider this post
      # changed. 
      ###

      post = Post.posts.get(post_id)
      @original_frames = Object.toJSON(post.frames_pending)

      ### In the off-chance that the frames_pending that came back differs from what we
      # requested, update the display. 
      ###

      @update()
    if finished
      finished()
    return
  ).bind(this)
  return

FrameEditor::create_image_frame = ->
  div = $(document.createElement('div'))
  div.className = 'frame-editor-frame-box'

  ### Disable pointer-events on the image frame, so the handle cursors always
  # show up even when an image frame lies on top of it. 
  ###

  div.style.pointerEvents = 'none'
  # div.style.opacity=0.1;
  @main_frame.appendChild div
  @image_frames.push div
  create_drag_box div
  return

FrameEditor::update_image_frame = (frame_idx) ->
  post = Post.posts.get(@post_id)
  frame = post.frames_pending[frame_idx]

  ### If the focused frame is being modified, update the corner dragger as well. ###

  if frame_idx == @editing_frame
    i = 0
    while i < @corner_draggers.length
      @corner_draggers[i].update()
      ++i
  dimensions = frame_dimensions_to_image(frame, @image_dimensions, post)
  div = @image_frames[frame_idx]
  div.style.left = dimensions.left + 'px'
  div.style.top = dimensions.top + 'px'
  div.style.width = dimensions.width + 'px'
  div.style.height = dimensions.height + 'px'
  if frame_idx == @editing_frame
    div.addClassName 'focused-frame-box'
  else
    div.removeClassName 'focused-frame-box'
  return

### Append the given frame to the editor list. ###

FrameEditor::add_frame_to_list = (frame_idx) ->
  tbody = @container.down('.frame-list').down('TBODY')
  tr = $(document.createElement('TR'))
  tr.className = 'frame-row frame-' + frame_idx
  tr.frame_idx = frame_idx
  tbody.appendChild tr
  html = '<td><span class=\'frame-label\'>Frame ' + frame_idx + '</span></td>'
  html += '<td><input class=\'frame-left frame-dims\' size=4></td>'
  html += '<td><input class=\'frame-top frame-dims\' size=4></td>'
  html += '<td><input class=\'frame-width frame-dims\' size=4></td>'
  html += '<td><input class=\'frame-height frame-dims\' size=4></td>'
  html += '<td><a class=\'frame-delete frame-button-box\' href=\'#\'>X</a></td>'
  html += '<td><a class=\'frame-up frame-button-box\' href=\'#\'>⇡</a></td>'
  html += '<td><a class=\'frame-down frame-button-box\' href=\'#\'>⇣</a></td>'
  tr.innerHTML = html
  @update_frame_in_list frame_idx
  return

### Update the fields of frame_idx in the table. ###

FrameEditor::update_frame_in_list = (frame_idx) ->
  post = Post.posts.get(@post_id)
  frame = post.frames_pending[frame_idx]
  tbody = @container.down('.frame-list').down('TBODY')
  tr = tbody.down('.frame-' + frame_idx)
  tr.down('.frame-left').value = frame.source_left
  tr.down('.frame-top').value = frame.source_top
  tr.down('.frame-width').value = frame.source_width
  tr.down('.frame-height').value = frame.source_height
  return

### Commit changes in the frame list to the frame. ###

FrameEditor::update_frame_from_list = (frame_idx) ->
  post = Post.posts.get(@post_id)
  frame = post.frames_pending[frame_idx]
  tbody = @container.down('.frame-list').down('TBODY')
  tr = tbody.down('.frame-' + frame_idx)
  frame.source_left = tr.down('.frame-left').value
  frame.source_top = tr.down('.frame-top').value
  frame.source_width = tr.down('.frame-width').value
  frame.source_height = tr.down('.frame-height').value
  return

### Add a new default frame to the end of the list, update the table, and edit the new frame. ###

FrameEditor::add_frame = (new_frame) ->
  post = Post.posts.get(@post_id)
  if !new_frame?
    new_frame =
      source_top: post.height * 1 / 4
      source_left: post.width * 1 / 4
      source_width: post.width / 2
      source_height: post.height / 2
  post.frames_pending.push new_frame
  @add_frame_to_list post.frames_pending.length - 1
  @create_image_frame()
  @update_image_frame post.frames_pending.length - 1
  @focus post.frames_pending.length - 1
  post.frames_pending.length - 1

### Delete the specified frame. ###

FrameEditor::delete_frame = (frame_idx) ->
  post = Post.posts.get(@post_id)

  ### If we're editing this frame, switch to a nearby one. ###

  switch_to_frame = null
  if @editing_frame == frame_idx
    switch_to_frame = @editing_frame
    @focus null

    ### If we're deleting the bottom item on the list, switch to the item above it instead. ###

    if frame_idx == post.frames_pending.length - 1
      --switch_to_frame

    ### If that put it over the top, we're deleting the only item.  Focus no item. ###

    if switch_to_frame < 0
      switch_to_frame = null

  ### Remove the frame from the array. ###

  post.frames_pending.splice frame_idx, 1

  ### Renumber the table. ###

  @repopulate_table()

  ### Focus switch_to_frame, if any. ###

  @focus switch_to_frame
  return

FrameEditor::focus = (post_frame) ->
  row = undefined
  if @editing_frame == post_frame
    return
  if @editing_frame?
    row = @container.down('.frame-' + @editing_frame)
    row.removeClassName 'frame-focused'
  @editing_frame = post_frame
  if @editing_frame?
    row = @container.down('.frame-' + @editing_frame)
    row.addClassName 'frame-focused'
  i = 0
  while i < @corner_draggers.length
    @corner_draggers[i].set_post_frame @editing_frame
    ++i
  @update()
  return

### Close the frame editor.  Local changes are not saved or reverted. ###

FrameEditor::close = ->
  if !@post_id?
    return
  @post_id = null
  @editing_frame = null
  i = 0
  while i < @corner_draggers.length
    @corner_draggers[i].set_post_id null
    ++i
  if @keydown_handler
    @open_handlers.each (h) ->
      h.stop()
      return
    @open_handlers = []
  if @dragger
    @dragger.destroy()
  @dragger = null
  @container.hide()
  @main_frame.hide()
  @update_show_corner_drag()

  ### Clear the row table. ###

  tbody = @container.down('.frame-list').down('TBODY')
  while tbody.firstChild
    tbody.removeChild tbody.firstChild
  @original_frames = null
  @update()
  if @options.onClose
    @options.onClose this
  return

### Create the specified corner dragger. ###

window.CornerDragger = (container, part, options) ->
  @container = container
  @part = part
  @options = options
  box = container.down('.frame-editor-popup-div')

  ### Create a div inside each .frame-editor-popup-div floating on top of the image
  # to show the border of the frame. 
  ###

  frame_box = $(document.createElement('div'))
  frame_box.className = 'frame-editor-frame-box'
  create_drag_box frame_box
  box.appendChild frame_box
  @dragger = new DragElement(box,
    snap_pixels: 0
    ondown: ((e) ->
      element = document.elementFromPoint(e.x, e.y)

      ### If we clicked on a drag handle, use that handle.  Otherwise, choose the corner drag
      # handle for the corner we're in. 
      ###

      if element.hasClassName('frame-box-handle')
        @dragging_mode = element.frame_drag_cursor
      else if part == '.frame-editor-nw'
        @dragging_mode = 'nw-resize'
      else if part == '.frame-editor-ne'
        @dragging_mode = 'ne-resize'
      else if part == '.frame-editor-sw'
        @dragging_mode = 'sw-resize'
      else if part == '.frame-editor-se'
        @dragging_mode = 'se-resize'
      post = Post.posts.get(@post_id)
      frame = post.frames_pending[@post_frame]
      @dragging_anchor = frame_dimensions_to_image(frame, @image_dimensions, post)

      ### When dragging a handle, hide the cursor to get it out of the way. ###

      @dragger.overriden_drag_class = if @dragging_mode == 'move' then null else 'hide-cursor'

      ### Stop propagation of the event, so any other draggers in the chain don't start.  In
      # particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
      # Only do this if we're actually dragging, not if we aborted due to this.drag_to_create. 
      ###

      e.latest_event.stopPropagation()
      return
    ).bind(this)
    ondrag: ((e) ->
      post = Post.posts.get(@post_id)

      ### Invert the motion, since we're dragging the image around underneith the
      # crop frame instead of dragging the crop frame around. 
      ###

      dims = apply_drag(@dragging_mode, -e.aX, -e.aY, @image_dimensions, @dragging_anchor)

      ### Scale the changed dimensions back to the source resolution and apply them
      # to the frame. 
      ###

      source_dims = frame_dimensions_from_image(dims, @image_dimensions, post)
      post.frames_pending[@post_frame] = source_dims
      if @options.onUpdate
        @options.onUpdate()
      return
    ).bind(this))
  @update()
  return

###
# Set the post to show in the corner dragger.  If post_id is null, clear any displayed
# post.
#
# When the post ID is set, the post frame is always cleared.
###

CornerDragger::set_post_id = (post_id) ->
  @post_id = post_id
  @post_frame = null
  url = null
  img = @container.down('img')
  if post_id?
    post = Post.posts.get(@post_id)
    @image_dimensions =
      width: post.jpeg_width
      height: post.jpeg_height
    url = post.jpeg_url
    img.width = @image_dimensions.width
    img.height = @image_dimensions.height

  ### Don't change the image if it's already set; it causes Chrome to reprocess the
  # image. 
  ###

  if img.src != url
    img.src = url
    if Prototype.Browser.WebKit and url

      ### Decoding in Chrome takes long enough to be visible.  Hourglass the cursor while it runs. ###

      document.documentElement.addClassName 'hourglass'
      (->
        document.documentElement.removeClassName 'hourglass'
        return
      ).defer()
  @update()
  return

CornerDragger::set_post_frame = (post_frame) ->
  @post_frame = post_frame
  @update()
  return

CornerDragger::update = ->
  if !@post_id? or !@post_frame?
    return
  post = Post.posts.get(@post_id)
  frame = post.frames_pending[@post_frame]
  dims = frame_dimensions_to_image(frame, @image_dimensions, post)
  div = @container

  ### Update the drag/frame box. ###

  box = @container.down('.frame-editor-frame-box')
  box.style.left = dims.left + 'px'
  box.style.top = dims.top + 'px'
  box.style.width = dims.width + 'px'
  box.style.height = dims.height + 'px'

  ### Recenter the corner box. ###

  top = dims.top
  left = dims.left
  if @part == '.frame-editor-ne' or @part == '.frame-editor-se'
    left += dims.width
  if @part == '.frame-editor-sw' or @part == '.frame-editor-se'
    top += dims.height
  offset_height = div.offsetHeight / 2
  offset_width = div.offsetWidth / 2

  ###
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-ne") offset_height -= div.offsetHeight/4;
  if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se") offset_height += div.offsetHeight/4;
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-sw") offset_width -= div.offsetWidth/4;
  if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se") offset_width += div.offsetWidth/4;
  ###

  left -= offset_width
  top -= offset_height

  ### If the region is small enough that we don't have enough to fill the corner
  # frames, push the frames inward so they line up. 
  ###

  if @part == '.frame-editor-nw' or @part == '.frame-editor-sw'
    left = Math.min(left, dims.left + dims.width / 2 - (div.offsetWidth))
  if @part == '.frame-editor-ne' or @part == '.frame-editor-se'
    left = Math.max(left, dims.left + dims.width / 2)
  if @part == '.frame-editor-nw' or @part == '.frame-editor-ne'
    top = Math.min(top, dims.top + dims.height / 2 - (div.offsetHeight))
  if @part == '.frame-editor-sw' or @part == '.frame-editor-se'
    top = Math.max(top, dims.top + dims.height / 2)
  img = @container.down('.frame-editor-popup-div')
  img.style.marginTop = -top + 'px'
  img.style.marginLeft = -left + 'px'
  return
