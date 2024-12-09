Object.extend Element.Methods,
  showBase: Element.show
  show: (element, visible) ->
    if visible or !visible?
      $(element).showBase()
    else
      $(element).hide()
  isParentNode: (element, parentNode) ->
    while element
      if element == parentNode
        return true
      element = element.parentNode
    false
Element.addMethods()

window.InitTextAreas = ->
  $$('TEXTAREA').each (elem) ->
    form = elem.up('FORM')
    if !form
      return
    if elem.set_login_handler
      return
    elem.set_login_handler = true
    OnKey 13, {
      ctrlKey: true
      AllowInputFields: true
      AllowTextAreaFields: true
      Element: elem
    }, (f) ->
      form.requestSubmit()
      return
    return
  return

### Return the squared distance between two points. ###
window.distance_squared = (x1, y1, x2, y2) ->
  (x1 - x2) ** 2 + (y1 - y2) ** 2

Prototype.Browser.AndroidWebKit = navigator.userAgent.indexOf('Android') != -1 and navigator.userAgent.indexOf('WebKit') != -1

# Some UI simply doesn't make sense on a touchscreen, and may need to be disabled or changed.
# It'd be nice if this could be done generically, but this is the best available so far...
Prototype.BrowserFeatures.Touchscreen =
  # iOS WebKit has window.Touch, a constructor for Touch events.
  window.Touch? ||
  # Mozilla/5.0 (Linux; U; Android 2.2; en-us; sdk Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1
  navigator.userAgent.indexOf('Mobile Safari/') != -1 ||
  # Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_2 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Mobile/8C134
  navigator.userAgent.indexOf('Mobile/') != -1

### When element is dragged, the document moves around it.  If scroll_element is true, the
# element should be positioned (eg. position: absolute), and the element itself will be
# scrolled. 
###

window.DragElement = (element, options) ->
  $(document.body).addClassName 'not-dragging'
  @options = options or {}
  if !@options.snap_pixels?
    @options.snap_pixels = 10
  @ignore_mouse_events_until = null
  @mousemove_event = @mousemove_event.bindAsEventListener(this)
  @mousedown_event = @mousedown_event.bindAsEventListener(this)
  @dragstart_event = @dragstart_event.bindAsEventListener(this)
  @mouseup_event = @mouseup_event.bindAsEventListener(this)
  @click_event = @click_event.bindAsEventListener(this)
  @selectstart_event = @selectstart_event.bindAsEventListener(this)
  @touchmove_event = @touchmove_event.bindAsEventListener(this)
  @touchstart_event = @touchstart_event.bindAsEventListener(this)
  @touchend_event = @touchend_event.bindAsEventListener(this)
  @move_timer_update = @move_timer_update.bind(this)
  @element = element
  @dragging = false
  @drag_handlers = []
  @handlers = []

  ###
  # Starting drag on mousedown works in most browsers, but has an annoying side-
  # effect: we need to stop the event to prevent any browser drag operations from
  # happening, and that'll also prevent clicking the element from focusing the
  # window.  Stop the actual drag in dragstart.  We won't get mousedown in
  # Opera, but we don't need to stop it there either.
  #
  # Sometimes drag events can leak through, and attributes like -moz-user-select may
  # be needed to prevent it.
  ###

  if !options.no_mouse
    @handlers.push element.on('mousedown', @mousedown_event)
    @handlers.push element.on('dragstart', @dragstart_event)
  if !options.no_touch
    @handlers.push element.on('touchstart', @touchstart_event)
    @handlers.push element.on('touchmove', @touchmove_event)

  ###
  # We may or may not get a click event after mouseup.  This is a pain: if we get a
  # click event, we need to cancel it if we dragged, but we may not get a click event
  # at all; detecting whether a click event came from the drag or not is difficult.
  # Cancelling mouseup has no effect.  FF, IE7 and Opera still send the click event
  # if their dragstart or mousedown event is cancelled; WebKit doesn't.
  ###

  if !Prototype.Browser.WebKit
    @handlers.push element.on('click', @click_event)
  return

DragElement::destroy = ->
  @stop_dragging null, true
  @handlers.each (h) ->
    h.stop()
    return
  @handlers = []
  return

DragElement::move_timer_update = ->
  @move_timer = null
  if !@options.ondrag
    return
  if !@last_event_params?
    return
  last_event_params = @last_event_params
  @last_event_params = null
  x = last_event_params.x
  y = last_event_params.y
  anchored_x = x - (@anchor_x)
  anchored_y = y - (@anchor_y)
  relative_x = x - (@last_x)
  relative_y = y - (@last_y)
  @last_x = x
  @last_y = y
  if @options.ondrag
    @options.ondrag
      dragger: this
      x: x
      y: y
      aX: anchored_x
      aY: anchored_y
      dX: relative_x
      dY: relative_y
      latest_event: last_event_params.event
  return

DragElement::mousemove_event = (event) ->
  event.stop()
  scrollLeft = window.pageXOffset or document.documentElement.scrollLeft or document.body.scrollLeft
  scrollTop = window.pageYOffset or document.documentElement.scrollTop or document.body.scrollTop
  x = event.pointerX() - scrollLeft
  y = event.pointerY() - scrollTop
  @handle_move_event event, x, y
  return

DragElement::touchmove_event = (event) ->

  ### Ignore touches other than the one we started with. ###

  touch = null
  i = 0
  while i < event.changedTouches.length
    t = event.changedTouches[i]
    if t.identifier == @dragging_touch_identifier
      touch = t
      break
    ++i
  if !touch?
    return
  event.preventDefault()

  ### If a touch drags over the bottom navigation bar in Safari and is released while outside of
  # the viewport, the touchend event is never sent.  Work around this by cancelling the drag
  # if we get too close to the end.  Don't do this if we're in standalone (web app) mode, since
  # there's no navigation bar. 
  ###

  if !window.navigator.standalone and touch.pageY > window.innerHeight - 10
    console.debug 'Dragged off the bottom'
    @stop_dragging event, true
    return
  x = touch.pageX
  y = touch.pageY
  @handle_move_event event, x, y
  return

DragElement::handle_move_event = (event, x, y) ->
  if !@dragging
    return
  if !@dragged
    distance = (x - (@anchor_x)) ** 2 + (y - (@anchor_y)) ** 2
    snap_pixels = @options.snap_pixels
    snap_pixels *= snap_pixels
    if distance < snap_pixels
      return
  if !@dragged
    if @options.onstartdrag

      ### Call the onstartdrag callback.  If it returns true, cancel the drag. ###

      if @options.onstartdrag(
          handler: this
          latest_event: event)
        @dragging = false
        return
    @dragged = true
    $(document.body).addClassName @overriden_drag_class or 'dragging'
    $(document.body).removeClassName 'not-dragging'
  @last_event_params =
    x: x
    y: y
    event: event
  if @dragging_by_touch and Prototype.Browser.AndroidWebKit

    ### Touch events on Android tend to queue up when they come in faster than we
    # can process.  Set a timer, so we discard multiple events in quick succession. 
    ###

    if !@move_timer?
      @move_timer = window.setTimeout(@move_timer_update, 10)
  else
    @move_timer_update()
  return

DragElement::mousedown_event = (event) ->
  if !event.isLeftClick()
    return

  ### Check if we're temporarily ignoring mouse events. ###

  if @ignore_mouse_events_until?
    now = (new Date).valueOf()
    if now < @ignore_mouse_events_until
      return
    @ignore_mouse_events_until = null
  scrollLeft = window.pageXOffset or document.documentElement.scrollLeft or document.body.scrollLeft
  scrollTop = window.pageYOffset or document.documentElement.scrollTop or document.body.scrollTop
  x = event.pointerX() - scrollLeft
  y = event.pointerY() - scrollTop
  @start_dragging event, false, x, y, 0
  return

DragElement::touchstart_event = (event) ->

  ### If we have multiple touches, find the first one that actually refers to us. ###

  touch = null
  i = 0
  while i < event.changedTouches.length
    t = event.changedTouches[i]
    if !t.target.isParentNode(@element)
      ++i
      continue
    touch = t
    break
    ++i
  if !touch?
    return
  x = touch.pageX
  y = touch.pageY
  @start_dragging event, true, x, y, touch.identifier
  return

DragElement::start_dragging = (event, touch, x, y, touch_identifier) ->
  if @dragging_touch_identifier?
    return

  ### If we've been started with a touch event, only listen for touch events.  If we've
  # been started with a mouse event, only listen for mouse events.  We may receive
  # both sets of events, and the anchor coordinates for the two may not be compatible. 
  ###

  @drag_handlers.push document.on('selectstart', @selectstart_event)
  @drag_handlers.push Element.on(window, 'pagehide', @pagehide_event.bindAsEventListener(this))
  if touch
    @drag_handlers.push document.on('touchend', @touchend_event)
    @drag_handlers.push document.on('touchcancel', @touchend_event)
    @drag_handlers.push document.on('touchmove', @touchmove_event)
  else
    @drag_handlers.push document.on('mouseup', @mouseup_event)
    @drag_handlers.push document.on('mousemove', @mousemove_event)
  @dragging = true
  @dragged = false
  @dragging_by_touch = touch
  @dragging_touch_identifier = touch_identifier
  @anchor_x = x
  @anchor_y = y
  @last_x = @anchor_x
  @last_y = @anchor_y
  if @options.ondown
    @options.ondown
      dragger: this
      x: x
      y: y
      latest_event: event
  return

DragElement::pagehide_event = (event) ->
  @stop_dragging event, true
  return

DragElement::touchend_event = (event) ->

  ### If our touch was released, stop the drag. ###

  i = 0
  while i < event.changedTouches.length
    t = event.changedTouches[i]
    if t.identifier == @dragging_touch_identifier
      @stop_dragging event, event.type == 'touchcancel'

      ###
      # Work around a bug on iPhone.  The mousedown and mouseup events are sent after
      # the touch is released, instead of when they should be (immediately following
      # touchstart and touchend).  This means we'll process each touch as a touch,
      # then immediately after as a mouse press, and fire ondown/onup events for each.
      #
      # We can't simply ignore mouse presses if touch events are supported; some devices
      # will support both touches and mice and both types of events will always need to
      # be handled.
      #
      # After a touch is released, ignore all mouse presses for a little while.  It's
      # unlikely that the user will touch an element, then immediately click it.
      ###

      @ignore_mouse_events_until = (new Date).valueOf() + 500
      return
    ++i
  return

DragElement::mouseup_event = (event) ->
  if !event.isLeftClick()
    return
  @stop_dragging event, false
  return

### If cancelling is true, we're stopping for a reason other than an explicit mouse/touch
# release. 
###

DragElement::stop_dragging = (event, cancelling) ->
  if @dragging
    @dragging = false
    $(document.body).removeClassName @overriden_drag_class or 'dragging'
    $(document.body).addClassName 'not-dragging'
    if @options.onenddrag
      @options.onenddrag this
  @drag_handlers.each (h) ->
    h.stop()
    return
  @drag_handlers = []
  @dragging_touch_identifier = null
  if @options.onup
    @options.onup
      dragger: this
      latest_event: event
      cancelling: cancelling
  return

DragElement::click_event = (event) ->

  ### If this click was part of a drag, cancel the click. ###

  if @dragged
    event.stop()
  @dragged = false
  return

DragElement::dragstart_event = (event) ->
  event.preventDefault()
  return

DragElement::selectstart_event = (event) ->

  ### We need to stop selectstart to prevent drag selection in Chrome.  However, we need
  # to work around a bug: if we stop the event of an INPUT element, it'll prevent focusing
  # on that element entirely.  We shouldn't prevent selecting the text in the input box,
  # either. 
  ###

  if event.target.tagName != 'INPUT'
    event.stop()
  return
