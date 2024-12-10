export default class Navigator
  constructor: (container, target) ->
    @container = container
    @target = target
    @hovering = false
    @autohide = false
    @img = @container.down('.image-navigator-img')
    @container.show()
    @handlers = []
    @handlers.push @container.on('mousedown', @mousedown_event)
    @handlers.push @container.on('mouseover', @mouseover_event)
    @handlers.push @container.on('mouseout', @mouseout_event)
    @dragger = new DragElement(@container, snap_pixels: 0, onenddrag: @enddrag, ondrag: @ondrag)


  set_image: (image_url, width, height) ->
    @img.src = image_url
    @img.width = width
    @img.height = height


  enable: (enabled) ->
    @container.show enabled


  mouseover_event: (e) =>
    return if @container.contains(e.relatedTarget)

    console.debug "over #{e.target.className}, #{@container.className}, #{@container.contains(e.target)}"
    @hovering = true
    @update_visibility()


  mouseout_event: (e) =>
    return if @container.contains(e.relatedTarget)

    console.debug "out #{e.target.className}"
    @hovering = false
    @update_visibility()


  mousedown_event: (e) =>
    x = e.pointerX()
    y = e.pointerY()
    coords = @get_normalized_coords(x, y)
    @center_on_position coords


  enddrag: (e) =>
    @shift_lock_anchor = null
    @locked_to_x = null
    @update_visibility()


  ondrag: (e) =>
    coords = @get_normalized_coords(e.x, e.y)
    if e.latest_event.shiftKey != @shift_lock_anchor?

      # The shift key has been pressed or released.
      if e.latest_event.shiftKey
        # The shift key was just pressed.  Remember the position we were at when it was
        # pressed.
        @shift_lock_anchor = [
          coords[0]
          coords[1]
        ]
      else
        # The shift key was released.
        @shift_lock_anchor = null
        @locked_to_x = null
    @center_on_position coords


  image_position_changed: (percent_x, percent_y, height_percent, width_percent) ->

    # When the image is moved or the visible area is resized, update the cursor rectangle.
    cursor = @container.down('.navigator-cursor')
    cursor.setStyle
      top: @img.height * (percent_y - (height_percent / 2)) + 'px'
      left: @img.width * (percent_x - (width_percent / 2)) + 'px'
      width: @img.width * width_percent + 'px'
      height: @img.height * height_percent + 'px'


  get_normalized_coords: (x, y) ->
    offset = @img.cumulativeOffset()
    x -= offset.left
    y -= offset.top
    x /= @img.width
    y /= @img.height

    [x, y]


  # x and y are absolute window coordinates.
  center_on_position: (coords) ->
    if @shift_lock_anchor
      if !@locked_to_x?

        # Only change the coordinate with the greater delta.
        change_x = Math.abs(coords[0] - (@shift_lock_anchor[0]))
        change_y = Math.abs(coords[1] - (@shift_lock_anchor[1]))

        # Only lock to moving vertically or horizontally after we've moved a small distance
        # from where shift was pressed.
        if change_x > 0.1 || change_y > 0.1
          @locked_to_x = change_x > change_y

      # If we've chosen an axis to lock to, apply it.
      if @locked_to_x?
        if @locked_to_x
          coords[1] = @shift_lock_anchor[1]
        else
          coords[0] = @shift_lock_anchor[0]
    coords[0] = Math.max(0, Math.min(coords[0], 1))
    coords[1] = Math.max(0, Math.min(coords[1], 1))
    @target.fire 'viewer:center-on',
      x: coords[0]
      y: coords[1]


  set_autohide: (autohide) ->
    @autohide = autohide
    @update_visibility()


  update_visibility: ->
    box = @container.down('.image-navigator-box')
    visible = !@autohide || @hovering || @dragger.dragging
    box.style.visibility = if visible then 'visible' else 'hidden'


  destroy: ->
    @dragger.destroy()
    @handlers.each (h) -> h.stop()
    @dragger = @handlers = null
    @container.hide()
