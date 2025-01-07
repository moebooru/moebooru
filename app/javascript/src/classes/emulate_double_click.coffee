import { distanceSquared } from 'src/utils/math'
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
  if !last_click?
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

  # Check that the clicks aren't too far apart.
  distance = distanceSquared(this_touch.screenX, this_touch.screenY, last_click.position[0], last_click.position[1])
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
  if !@last_click?
    return
  last_click_identifier = @last_click.identifier
  if !last_click_identifier?
    return
  last_click_position = @last_click.position
  this_click = event.changedTouches[0]
  if this_click.identifier == last_click_identifier

    # If the touch moved too far when it was removed, don't fire a doubleclick; for
    # example, two quick swipe gestures aren't a double-click. 
    distance = distanceSquared(this_click.screenX, this_click.screenY, last_click_position[0], last_click_position[1])
    if distance > 500
      @last_click = null
      return
  return
