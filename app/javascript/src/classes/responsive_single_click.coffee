import { distanceSquared } from 'src/utils/math'

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

  if @last_touch?
    console.debug 'Cancelling click (multitouch)'
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
  if !last_touch?
    return
  @last_touch = null
  touch = event.changedTouches[0]
  this_touch = [
    touch.screenX
    touch.screenY
  ]

  # Don't trigger a click if the point has moved too far.
  distance = distanceSquared(this_touch[0], this_touch[1], last_touch[0], last_touch[1])
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
