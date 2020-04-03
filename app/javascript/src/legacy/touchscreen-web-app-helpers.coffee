###
# This file implements several helpers for fixing up full-page web apps on touchscreen
# browsers:
#
# EmulateDoubleClick
# ResponsiveSingleClick
# PreventDragScrolling
#
# Most of these are annoying hacks to work around the fact that WebKit on browsers was
# designed with displaying scrolling webpages in mind, apparently without consideration
# for full-screen applications: pages that should fill the screen at all times.  Most
# of the browser mobile hacks no longer make sense: separate display viewports, touch
# dragging, double-click zooming and their associated side-effects.
###

###
# Work around a bug on many touchscreen browsers: even when the page isn't
# zoomable, dblclick is never fired.  We have to emulate it.
#
# This isn't an exact emulation of the event behavior:
#
# - It triggers from touchstart rather than mousedown.  The second mousedown
#   of a double click isn't being fired reliably in Android's WebKit.
#
# - preventDefault on the triggering event should prevent a dblclick, but
#   we can't find out if it's been called; there's nothing like Firefox's
#   getPreventDefault.  We could mostly emulate this by overriding
#   Event.preventDefault to set a flag that we can read.
#
# - The conditions for a double click won't match the ones of the platform.
#
# This is needed on Android and iPhone's WebKit.
#
# Note that this triggers a minor bug on Android: after firing a dblclick event,
# we no longer receive mousemove events until the touch is released, which means
# PreventDragScrolling can't cancel dragging.
###

window.EmulateDoubleClick = ->
  @touchstart_event = @touchstart_event.bindAsEventListener(this)
  @touchend_event = @touchend_event.bindAsEventListener(this)
  @last_click = null
  window.addEventListener 'touchstart', @touchstart_event, false
  window.addEventListener 'touchend', @touchend_event, false
  return

EmulateDoubleClick::touchstart_event = (event) ->
  this_touch = event.changedTouches[0]
  last_click = @last_click

  ### Don't store event.changedTouches or any of its contents.  Some browsers modify these
  # objects in-place between events instead of properly returning unique events. 
  ###

  this_click = 
    timeStamp: event.timeStamp
    target: event.target
    identifier: this_touch.identifier
    position: [
      this_touch.screenX
      this_touch.screenY
    ]
    clientPosition: [
      this_touch.clientX
      this_touch.clientY
    ]
  @last_click = this_click
  if last_click == null or last_click == undefined
    return

  ### If the first tap was never released then this is a multitouch double-tap.
  # Clear the original tap and don't fire anything. 
  ###

  if event.touches.length > 1
    return

  ### Check that not too much time has passed. ###

  time_since_previous = event.timeStamp - (last_click.timeStamp)
  if time_since_previous > 500
    return

  ### Check that the clicks aren't too far apart. ###

  distance = (this_touch.screenX - (last_click.position[0])) ** 2 + (this_touch.screenY - (last_click.position[1])) ** 2
  if distance > 500
    return
  if event.target != last_click.target
    return

  ### Synthesize a dblclick event.  Use the coordinates of the first click as the location
  # and not the second click, since if the position matters the user's first click of
  # a double-click is probably more precise than the second. 
  ###

  e = document.createEvent('MouseEvent')
  e.initMouseEvent 'dblclick', true, true, window, 2, last_click.position[0], last_click.position[1], last_click.clientPosition[0], last_click.clientPosition[1], false, false, false, false, 0, null
  @last_click = null
  event.target.dispatchEvent e
  return

EmulateDoubleClick::touchend_event = (event) ->
  if @last_click == null or @last_click == undefined
    return
  last_click_identifier = @last_click.identifier
  if last_click_identifier == null or last_click_identifier == undefined
    return
  last_click_position = @last_click.position
  this_click = event.changedTouches[0]
  if this_click.identifier == last_click_identifier

    ### If the touch moved too far when it was removed, don't fire a doubleclick; for
    # example, two quick swipe gestures aren't a double-click. 
    ###

    distance = (this_click.screenX - (last_click_position[0])) ** 2 + (this_click.screenY - (last_click_position[1])) ** 2
    if distance > 500
      @last_click = null
      return
  return

###
# Mobile WebKit has serious problems with the click event: it delays them for the
# entire double-click timeout, and if a double-click happens it doesn't deliver the
# click at all.  This makes clicks unresponsive, and it has this behavior even
# when the page can't be zoomed, which means nothing happens at all.
#
# Generate click events from touchend events to bypass this mess.
###

window.ResponsiveSingleClick = ->
  @click_event = @click_event.bindAsEventListener(this)
  @touchstart_event = @touchstart_event.bindAsEventListener(this)
  @touchend_event = @touchend_event.bindAsEventListener(this)
  @last_touch = null
  window.addEventListener 'touchstart', @touchstart_event, false
  window.addEventListener 'touchend', @touchend_event, false

  ### This is a capturing listener, so we can intercept clicks before they're
  # delivered to anyone. 
  ###

  window.addEventListener 'click', @click_event, true
  return

ResponsiveSingleClick::touchstart_event = (event) ->

  ### If we get a touch while we already have a touch, it's multitouch, which is never
  # a click, so cancel the click. 
  ###

  if @last_touch != null and @last_touch != undefined
    debug 'Cancelling click (multitouch)'
    @last_touch = null
    return

  ### Watch out: in older versions of WebKit, the event.touches array and the items inside
  # it are actually modified in-place when the user drags.  That means that we can't just
  # save the entire array for comparing in touchend. 
  ###

  touch = event.changedTouches[0]
  @last_touch = [
    touch.screenX
    touch.screenY
  ]
  return

ResponsiveSingleClick::touchend_event = (event) ->
  last_touch = @last_touch
  if last_touch == null or last_touch == undefined
    return
  @last_touch = null
  touch = event.changedTouches[0]
  this_touch = [
    touch.screenX
    touch.screenY
  ]

  ### Don't trigger a click if the point has moved too far. ###

  distance = distance_squared(this_touch[0], this_touch[1], last_touch[0], last_touch[1])
  if distance > 50
    return
  e = document.createEvent('MouseEvent')
  e.initMouseEvent 'click', true, true, window, 1, touch.screenX, touch.screenY, touch.clientX, touch.clientY, false, false, false, false, 0, null
  e.synthesized_click = true

  ### If we dispatch the click immediately, EmulateDoubleClick won't receive a
  # touchstart for the next click.  Defer dispatching it until we return. 
  ###

  (->
    event.target.dispatchEvent e
    return
  ).defer()
  return

### Capture and cancel all clicks except the ones we generate. ###

ResponsiveSingleClick::click_event = (event) ->
  if !event.synthesized_click
    event.stop()
  return

### Stop all touchmove events on the document, to prevent dragging the window around. ###

window.PreventDragScrolling = ->
  Element.observe document, 'touchmove', (event) ->
    event.preventDefault()
    return
  return

###
# Save the URL hash to local DOM storage when it changes.  When called, restores the
# previously saved hash.
#
# This is used on the iPhone only, and only when operating in web app mode (window.standalone).
# The iPhone doesn't update the URL hash saved in the web app shortcut, nor does it
# remember the current URL when using make-believe multitasking, which means every time
# you switch out and back in you end up back to wherever you were when you first created
# the web app shortcut.  Saving the URL hash allows switching out and back in without losing
# your place.
#
# This should only be used in environments where it's been tested and makes sense.  If used
# in a browser, or in a web app environment that properly tracks the URL hash, this will
# just interfere with normal operation.
###

MaintainUrlHash = ->

  ### This requires DOM storage. ###

  if LocalStorageDisabled()
    return

  ### When any part of the URL hash changes, save it. ###

  update_stored_hash = (changed_hash_keys, old_hash, new_hash) ->
    hash = localStorage.current_hash = UrlHash.get_raw_hash()
    return

  UrlHash.observe null, update_stored_hash

  ### Restore the previous hash, if any. ###

  hash = localStorage.getItem('current_hash')
  if hash
    UrlHash.set_raw_hash hash
  return

###
# In some versions of the browser, iPhones don't send resize events after an
# orientation change, so we need to fire it ourself.  Try not to do this if not
# needed, so we don't fire spurious events.
#
# This is never needed in web app mode.
#
# Needed on user-agents:
# iPhone OS 4_0_2 ... AppleWebKit/532.9 ... Version/4.0.5
# iPhone OS 4_1 ... AppleWebKit/532.9 ... Version/4.0.5
#
# Not needed on:
# (iPad, OS 3.2)
# CPU OS 3_2 ... AppleWebKit/531.1.10 ... Version/4.0.4
# iPhone OS 4_2 ... AppleWebKit/533.17.9 ... Version/5.0.2
#
# This seems to be specific to Version/4.0.5.
###

window.SendMissingResizeEvents = ->
  if window.navigator.standalone
    return
  if navigator.userAgent.indexOf('Version/4.0.5') == -1
    return
  last_seen_orientation = window.orientation
  window.addEventListener 'orientationchange', ((e) ->
    if last_seen_orientation == window.orientation
      return
    last_seen_orientation = window.orientation
    debug 'dispatch fake resize event'
    e = document.createEvent('Event')
    e.initEvent 'resize', true, true
    document.documentElement.dispatchEvent e
    return
  ), true
  return

window.InitializeFullScreenBrowserHandlers = ->

  ### These handlers deal with heavily browser-specific issues.  Only install them
  # on browsers that have been tested to need them. 
  ###

  if navigator.userAgent.indexOf('Android') != -1 and navigator.userAgent.indexOf('WebKit') != -1
    new ResponsiveSingleClick
    new EmulateDoubleClick
  else if (navigator.userAgent.indexOf('iPhone') != -1 or navigator.userAgent.indexOf('iPad') != -1 or navigator.userAgent.indexOf('iPod') != -1) and navigator.userAgent.indexOf('WebKit') != -1
    new ResponsiveSingleClick
    new EmulateDoubleClick

    ### In web app mode only: ###

    if window.navigator.standalone
      MaintainUrlHash()
    SendMissingResizeEvents()
  PreventDragScrolling()
  return

window.SwipeHandler = (element) ->
  @element = element
  @dragger = new DragElement(element,
    ondrag: @ondrag.bind(this)
    onstartdrag: @startdrag.bind(this))
  return

SwipeHandler::startdrag = ->
  @swiped_horizontal = false
  @swiped_vertical = false
  return

SwipeHandler::ondrag = (e) ->
  if !@swiped_horizontal
    # XXX: need a guessed DPI
    if Math.abs(e.aX) > 100
      @element.fire 'swipe:horizontal', right: e.aX > 0
      @swiped_horizontal = true
  if !@swiped_vertical
    if Math.abs(e.aY) > 100
      @element.fire 'swipe:vertical', down: e.aY > 0
      @swiped_vertical = true
  return

SwipeHandler::destroy = ->
  @dragger.destroy()
  return
