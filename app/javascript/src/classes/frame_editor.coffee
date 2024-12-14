import DragElement from 'src/classes/drag_element'
import { applyDrag, createDragBox } from 'src/utils/drag_box'
import { frameDimensionsFromImage, frameDimensionsToImage } from 'src/utils/frame_math'
import { clamp } from 'src/utils/math'
import CornerDragger from './corner_dragger'

$ = jQuery

export default class FrameEditor
  constructor: (@container, @image_container, @popup_container, @options) ->
    @show_corner_drag = true
    @image_frames = []

    # Event handlers which are set only while the tag editor is open:
    @open_handlers = []

    # Set up the four parts of the corner dragger.
    @corner_draggers = [
      '.frame-editor-nw'
      '.frame-editor-ne'
      '.frame-editor-sw'
      '.frame-editor-se'
    ].map (part) =>
      target = @popup_container.querySelector(part)
      cornerDraggerOptions =
        onUpdate: =>
          @update_frame_in_list @editing_frame
          @update_image_frame @editing_frame
          return

      new CornerDragger(target, part, cornerDraggerOptions)

    # Create the main frame.  This sits on top of the image, receives mouse events and
    # holds the individual frames.
    div = document.createElement('div')
    div.className = 'frame-editor-main-frame'
    div.style.position = 'absolute'
    div.style.left = '0'
    div.style.top = '0'
    div.style.display = 'none'
    @image_container.appendChild div
    @main_frame = div

    $container = $(@container)

    # Frame editor buttons:
    $container.find('.frame-editor-add').on 'click', (e) =>
      e.preventDefault()
      @add_frame()
      return

    # Buttons in the frame table:
    $container.on 'click', '.frame-label', (e) =>
      e.preventDefault()
      frame_idx = e.currentTarget.closest('.frame-row').frame_idx
      @focus frame_idx
      return

    $container.on 'click', '.frame-delete', (e) =>
      e.preventDefault()
      frame_idx = e.currentTarget.closest('.frame-row').frame_idx
      @delete_frame frame_idx
      return

    $container.on 'click', '.frame-up', (e) =>
      e.preventDefault()
      frame_idx = e.currentTarget.closest('.frame-row').frame_idx
      @move_frame frame_idx, frame_idx - 1
      return

    $container.on 'click', '.frame-down', (e) =>
      e.preventDefault()
      frame_idx = e.currentTarget.closest('.frame-row').frame_idx
      @move_frame frame_idx, frame_idx + 1
      return

    $container.find('table').on 'change', =>
      @form_data_changed()
      return


  move_frame: (frame_idx, frame_idx_target) ->
    post = Post.posts.get(@post_id)
    frame_idx_target = clamp(frame_idx_target, 0, post.frames_pending.length - 1)
    return if frame_idx == frame_idx_target
    frame = post.frames_pending[frame_idx]
    post.frames_pending.splice frame_idx, 1
    post.frames_pending.splice frame_idx_target, 0, frame
    @repopulate_table()

    # Reset the focus.  If the item that was moved was focused, focus on it in
    # its new position.
    editing_frame = if @editing_frame == frame_idx then frame_idx_target else @editing_frame
    @editing_frame = null
    @focus editing_frame
    return

  form_data_changed: ->
    post = Post.posts.get(@post_id)
    for _frame, i in post.frames_pending
      @update_frame_from_list i
    @update()
    return

  set_drag_to_create: (enable) ->
    @drag_to_create = enable
    return

  update_show_corner_drag: ->
    shown = @post_id? && @editing_frame? && @show_corner_drag
    if Prototype.Browser.WebKit
      # Work around a WebKit (maybe just a Chrome) issue.  Images are downloaded immediately, but
      # they're only decompressed the first time they're actually painted on screen.  This happens
      # late, after all style is applied: hiding with display: none, visibility: hidden or even
      # opacity: 0 causes the image to not be decoded until it's displayed, which causes a huge
      # UI hitch the first time the user drags a box.  Work around this by setting opacity very
      # small; it'll trick it into decoding the image, but it'll clip to 0 when rendered.
      if shown
        @popup_container.style.opacity = 1
        @popup_container.style.pointerEvents = ''
        @popup_container.style.position = 'static'
      else
        @popup_container.style.opacity = 0.001

        # Make sure the invisible element doesn't interfere with the page; disable pointer-events
        # so it doesn't receive clicks, and set it to absolute so it doesn't affect the size of its
        # containing box.
        @popup_container.style.pointerEvents = 'none'
        @popup_container.style.position = 'absolute'
        @popup_container.style.top = '0px'
        @popup_container.style.right = '0px'
      @popup_container.style.display = ''
    else
      @popup_container.style.display = if shown then '' else 'none'

    for cornerDragger in @corner_draggers
      cornerDragger.update()

    return

  set_show_corner_drag: (enable) ->
    @show_corner_drag = enable
    @update_show_corner_drag()
    return

  set_image_dimensions: (width, height) ->
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

  # Like document.elementFromPoint, but returns an array of all elements at the given point.
  # If a top element is specified, stop if it's reached without including it in the list.
  elementArrayFromPoint: (x, y, top) ->
    elements = []
    loop
      element = document.elementFromPoint(x, y)
      if element == top || element == document.documentElement
        break
      element.original_display = element.style.display
      element.style.display = 'none'
      elements.push element

    # Restore the elements we just hid.
    for element in elements
      element.style.display = element.original_display
      element.original_display = null

    elements

  is_opened: ->
    @post_id?

  # Open the frame editor if it isn't already, and focus on the specified frame.
  open: (post_id) ->
    if !@image_dimensions?
      throw 'Must call set_image_dimensions before open'
    return if @post_id?
    @post_id = post_id
    @editing_frame = null
    @dragging_item = null
    @container.style.display = ''
    @main_frame.style.display = ''
    @update_show_corner_drag()
    post = Post.posts.get(@post_id)

    # Tell the corner draggers which post we're working on now, so they'll start
    # loading the JPEG version immediately if necessary.  Otherwise, we'll start
    # loading it the first time we focus a frame, which will hitch the editor for
    # a while in Chrome.
    for cornerDragger in @corner_draggers
      cornerDragger.set_post_id @post_id

    onKeydownDocument = (e) =>
      @discard() if e.keyCode == Event.KEY_ESC
      return
    $(document).on 'keydown', onKeydownDocument
    @open_handlers.push =>
      $(document).off 'keydown', onKeydownDocument

    # If we haven't done so already, make a backup of this post's frames.  We'll restore
    # from this later if the user cancels the edit.
    @original_frames = JSON.stringify(post.frames_pending)
    @repopulate_table()
    @create_dragger()
    if post.frames_pending.length > 0
      @focus 0
    @update()
    return

  create_dragger: ->
    @dragger?.destroy()
    dragElementOptions =
      ondown: (e) =>
        post = Post.posts.get(@post_id)

        # Figure out which element(s) we're clicking on.  The click may lie on a spot
        # where multiple frames overlap; make a list.
        #
        # Temporarily enable pointerEvents on the frames, so elementFromPoint will
        # resolve them.
        for frame in @image_frames
          frame.style.pointerEvents = 'all'

        clicked_elements = @elementArrayFromPoint(e.x, e.y, @main_frame)
        for frame in @image_frames
          frame.style.pointerEvents = 'none'

        # If we clicked on a handle, prefer it over frame bodies at the same spot.
        element = null
        for clickedElement in clicked_elements
          # If a handle was clicked, always prefer it.  Use the first handle we find,
          # so we prefer the corner handles (which are always on top) to edge handles.
          if clickedElement.classList.contains('frame-box-handle')
            element = clickedElement
            break

        # If a handle wasn't clicked, prefer the frame that's currently focused.
        if !element?
          for clickedElement in clicked_elements
            if !clickedElement.classList.contains('frame-editor-frame-box')
              clickedElement = clickedElement.closest('.frame-editor-frame-box')
            if @image_frames.indexOf(clickedElement) == @editing_frame
              element = clickedElement
              break

        # Otherwise, just use the first item that was found.
        element ?= clicked_elements[0]

        # If a handle was clicked on, find the frame element that contains it.
        frame_element = element

        if frame_element? && !frame_element.classList.contains('frame-editor-frame-box')
          frame_element = frame_element.closest('.frame-editor-frame-box')

        if frame_element?
          @dragging_new = false
        else
          # If we didn't click on a frame box at all, create a new one.
          return if !@drag_to_create
          @dragging_new = true

        # If the element we actually clicked on was one of the edge handles, set the drag
        # mode based on which one was clicked.
        if element? && element.classList.contains('frame-box-handle')
          @dragging_mode = element._frameDragCursor
        else
          @dragging_mode = 'move'
        if frame_element? && frame_element.classList.contains('frame-editor-frame-box')
          frame_idx = @image_frames.indexOf(frame_element)
          @dragging_idx = frame_idx
          frame = post.frames_pending[@dragging_idx]
          @dragging_anchor = frameDimensionsToImage(frame, @image_dimensions, post)
        @focus @dragging_idx

        # If we're dragging a handle, override the drag class so the pointer will
        # use the handle pointer instead of the drag pointer.
        @dragger.overriden_drag_class = if @dragging_mode == 'move' then null else @dragging_mode
        @dragger.options.snap_pixels = if @dragging_new then 10 else 0

        # Stop propagation of the event, so any other draggers in the chain don't start.  In
        # particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
        # Only do this if we're actually dragging, not if we aborted due to this.drag_to_create.
        e.latest_event.stopPropagation()
        return

      onup: (e) =>
        @dragging_idx = null
        @dragging_anchor = null
        return

      ondrag: (e) =>
        post = Post.posts.get(@post_id)
        dims = undefined
        source_dims = undefined
        if @dragging_new
          # Pick a dragging mode based on which way we were dragged.  This is a
          # little funny; we should probably be able to drag freely, not be fixed
          # to the first direction we drag.
          @dragging_mode =
            if e.aX > 0 and e.aY > 0
              'se-resize'
            else if e.aX > 0 and e.aY < 0
              'ne-resize'
            else if e.aX < 0 and e.aY > 0
              'sw-resize'
            else if e.aX < 0 and e.aY < 0
              'nw-resize'
          return if !@dragging_mode?
          @dragging_new = false

          # Create a new, empty frame.  When we get to the regular drag path below we'll
          # give it its real size, based on how far we've dragged so far.
          frame_offset = $(@main_frame).offset()
          dims =
            left: e.dragger.anchor_x - (frame_offset.left)
            top: e.dragger.anchor_y - (frame_offset.top)
            height: 0
            width: 0
          @dragging_anchor = dims
          source_dims = frameDimensionsFromImage(dims, @image_dimensions, post)
          @dragging_idx = @add_frame(source_dims)
          post.frames_pending[@editing_frame] = source_dims
        return if !@dragging_idx?
        dims = applyDrag(@dragging_mode, e.aX, e.aY, @image_dimensions, @dragging_anchor)

        # Scale the changed dimensions back to the source resolution and apply them
        # to the frame.
        post.frames_pending[@editing_frame] = frameDimensionsFromImage(dims, @image_dimensions, post)
        @update_frame_in_list @editing_frame
        @update_image_frame @editing_frame
        return

    @dragger = new DragElement(@main_frame, dragElementOptions)
    return

  repopulate_table: ->
    post = Post.posts.get(@post_id)

    # Clear the table.
    tbody = @container.querySelector('.frame-list tbody')
    while tbody.firstChild?
      tbody.removeChild tbody.firstChild

    # Clear the image frames.
    for imageFrame in @image_frames
      imageFrame.remove()
    @image_frames = []

    for _frame, i in post.frames_pending
      @add_frame_to_list i
      @create_image_frame()
      @update_image_frame i

    return

  update: ->
    @update_show_corner_drag()
    return if !@image_dimensions?
    post = Post.posts.get(@post_id)
    if post?
      for _frame, i in post.frames_pending
        @update_image_frame i

    return

  # If the frame editor is open, discard changes and close it.
  discard: ->
    return if !@post_id?

    # Save revert_to, and close the editor before reverting, to make sure closing
    # the editor doesn't change anything.
    revert_to = @original_frames
    post_id = @post_id
    @close()

    # Revert changes.
    post = Post.posts.get(post_id)
    post.frames_pending = JSON.parse(revert_to)
    return

  # Get the frames specifier for the post's frames.
  get_current_frames_spec: ->
    Post.posts.get(@post_id).frames_pending
      .map (frame) -> "#{frame.source_left}x#{frame.source_top},#{frame.source_width}x#{frame.source_height}"
      .join ';'

  # Return true if the frames have been changed.
  changed: ->
    Post.posts.get(@post_id) != @get_current_frames_spec()

  # Save changes to the post, if any.  If not null, call finished on completion.
  save: (finished) ->
    if !@post_id?
      finished?()
      return

    # Save the current post_id, so it's preserved when the AJAX completion function
    # below is run.
    post_id = @post_id
    post = Post.posts.get(post_id)
    frame = post.frames_pending
    spec = @get_current_frames_spec()

    if spec == post.frames_pending_string
      finished?()
      return

    Post.update_batch [{
      id: post_id
      frames_pending_string: spec
    }], (posts) =>
      if @post_id == post_id
        # The registered post has been changed, and we're still displaying it.  Grab the
        # new version, and updated original_frames so we no longer consider this post
        # changed.
        post = Post.posts.get(post_id)
        @original_frames = JSON.stringify(post.frames_pending)

        # In the off-chance that the frames_pending that came back differs from what we
        # requested, update the display.
        @update()
      finished?()
      return

    return

  create_image_frame: ->
    div = document.createElement('div')
    div.className = 'frame-editor-frame-box'

    # Disable pointer-events on the image frame, so the handle cursors always
    # show up even when an image frame lies on top of it.
    div.style.pointerEvents = 'none'
    # div.style.opacity=0.1;
    @main_frame.appendChild div
    @image_frames.push div
    createDragBox div
    return

  update_image_frame: (frame_idx) ->
    post = Post.posts.get(@post_id)
    frame = post.frames_pending[frame_idx]

    # If the focused frame is being modified, update the corner dragger as well.
    if frame_idx == @editing_frame
      for cornerDragger in @corner_draggers
        cornerDragger.update()

    dimensions = frameDimensionsToImage(frame, @image_dimensions, post)
    div = @image_frames[frame_idx]
    div.style.left = "#{dimensions.left}px"
    div.style.top = "#{dimensions.top}px"
    div.style.width = "#{dimensions.width}px"
    div.style.height = "#{dimensions.height}px"
    div.classList.toggle 'focused-frame-box', frame_idx == @editing_frame

    return

  # Append the given frame to the editor list.
  add_frame_to_list: (frame_idx) ->
    tbody = @container.querySelector('.frame-list tbody')
    tr = document.createElement('tr')
    tr.className = "frame-row frame-#{frame_idx}"
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

  # Update the fields of frame_idx in the table.
  update_frame_in_list: (frame_idx) ->
    post = Post.posts.get(@post_id)
    frame = post.frames_pending[frame_idx]
    tr = @container.querySelector(".frame-list tbody .frame-#{frame_idx}")
    tr.querySelector('.frame-left').value = frame.source_left
    tr.querySelector('.frame-top').value = frame.source_top
    tr.querySelector('.frame-width').value = frame.source_width
    tr.querySelector('.frame-height').value = frame.source_height
    return

  # Commit changes in the frame list to the frame.
  update_frame_from_list: (frame_idx) ->
    post = Post.posts.get(@post_id)
    frame = post.frames_pending[frame_idx]
    tr = @container.querySelector(".frame-list tbody .frame-#{frame_idx}")
    frame.source_left = tr.querySelector('.frame-left').value
    frame.source_top = tr.querySelector('.frame-top').value
    frame.source_width = tr.querySelector('.frame-width').value
    frame.source_height = tr.querySelector('.frame-height').value
    return

  # Add a new default frame to the end of the list, update the table, and edit the new frame.
  add_frame: (new_frame) ->
    post = Post.posts.get(@post_id)
    new_frame ?=
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

  # Delete the specified frame.
  delete_frame: (frame_idx) ->
    post = Post.posts.get(@post_id)

    # If we're editing this frame, switch to a nearby one.
    switch_to_frame = null
    if @editing_frame == frame_idx
      switch_to_frame = @editing_frame
      @focus null

      # If we're deleting the bottom item on the list, switch to the item above it instead.
      if frame_idx == post.frames_pending.length - 1
        --switch_to_frame

      # If that put it over the top, we're deleting the only item.  Focus no item.
      if switch_to_frame < 0
        switch_to_frame = null

    # Remove the frame from the array.
    post.frames_pending.splice frame_idx, 1

    # Renumber the table.
    @repopulate_table()

    # Focus switch_to_frame, if any.
    @focus switch_to_frame
    return

  focus: (post_frame) ->
    return if @editing_frame == post_frame

    if @editing_frame?
      @container.querySelector(".frame-#{@editing_frame}").classList.remove 'frame-focused'

    @editing_frame = post_frame
    if @editing_frame?
      @container.querySelector(".frame-#{@editing_frame}").classList.add 'frame-focused'

    for cornerDragger in @corner_draggers
      cornerDragger.set_post_frame @editing_frame

    @update()
    return

  # Close the frame editor.  Local changes are not saved or reverted.
  close: ->
    return if !@post_id?
    @post_id = null
    @editing_frame = null
    for cornerDragger in @corner_draggers
      cornerDragger.set_post_id null

    dispose() for dispose in @open_handlers
    @open_handlers = []

    @dragger?.destroy()
    @dragger = null
    @container.hide()
    @main_frame.hide()
    @update_show_corner_drag()

    # Clear the row table.
    tbody = @container.querySelector('.frame-list tbody')
    while tbody.firstChild
      tbody.removeChild tbody.firstChild
    @original_frames = null
    @update()
    @options.onClose?(@)
    return
