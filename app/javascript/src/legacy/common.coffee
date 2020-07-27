window.DANBOORU_VERSION =
  major: 6
  minor: 0
  build: 0


window.number_to_human_size = (size, precision) ->
  if !precision?
    precision = 1
  text = undefined
  size = Number(size)
  if size.toFixed(0) == '1'
    text = '1 Byte'
  else if size < 1024
    text = size.toFixed(0) + ' Bytes'
  else if size < 1024 * 1024
    text = (size / 1024).toFixed(precision) + ' KB'
  else if size < 1024 * 1024 * 1024
    text = (size / (1024 * 1024)).toFixed(precision) + ' MB'
  else if size < 1024 * 1024 * 1024 * 1024
    text = (size / (1024 * 1024 * 1024)).toFixed(precision) + ' GB'
  else
    text = (size / (1024 * 1024 * 1024 * 1024)).toFixed(precision) + ' TB'
  text = text.gsub(/([0-9]\.\d*?)0+ /, '#{1} ').gsub(/\. /, ' ')
  text

window.scale = (x, l1, h1, l2, h2) ->
  (x - l1) * (h2 - l2) / (h1 - l1) + l2

window.clamp = (n, min, max) ->
  Math.max Math.min(n, max), min

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
  setTextContent: (element, text) ->
    if element.innerText?
      element.innerText = text
    else
      element.textContent = text
    element
  recursivelyVisible: (element) ->
    while element != document.documentElement
      if !element.visible()
        return false
      element = element.parentNode
    true
Element.addMethods()
KeysDown = new Hash

### Many browsers eat keyup events if focus is lost while the button
# is pressed. 
###

document.observe 'blur', (e) ->
  KeysDown = new Hash
  return

window.OnKey = (key, options, press, release) ->
  if !options
    options = {}
  element = options['Element']
  if !element
    element = document
  if element == document and window.opera and !options.AlwaysAllowOpera
    return
  element.observe 'keyup', (e) ->
    if e.keyCode != key
      return
    KeysDown[e.keyCode] = false
    if release
      release e
    return
  element.observe 'keydown', (e) ->
    if e.keyCode != key
      return
    if e.metaKey
      return
    if e.shiftKey != ! !options.shiftKey
      return
    if e.altKey != ! !options.altKey
      return
    if e.ctrlKey != ! !options.ctrlKey
      return
    if !options.allowRepeat and KeysDown[e.keyCode]
      return
    KeysDown[e.keyCode] = true
    target = e.target
    if !options.AllowTextAreaFields and target.tagName == 'TEXTAREA'
      return
    if !options.AllowInputFields and target.tagName == 'INPUT'
      return
    if press and !press(e)
      return
    e.stop()
    e.preventDefault()
    return
  return

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
      $(form).simulate_submit()
      return
    return
  return

window.InitAdvancedEditing = ->
  if Cookie.get('show_advanced_editing') != '1'
    return
  $(document.documentElement).removeClassName 'hide-advanced-editing'
  return

### When we resume a user submit after logging in, we want to run submit events, as
# if the submit had happened normally again, but submit() doesn't do this.  Run
# a submit event manually. 
###

Element.addMethods 'FORM', simulate_submit: (form) ->
  form = $(form)
  if document.createEvent
    e = document.createEvent('HTMLEvents')
    e.initEvent 'submit', true, true
    form.dispatchEvent e
    if !e.stopped
      form.submit()
  else
    if form.fireEvent('onsubmit')
      form.submit()
  return
Element.addMethods simulate_anchor_click: (a, ev) ->
  a = $(a)
  if document.dispatchEvent
    if a.dispatchEvent(ev) and !ev.stopped
      window.location.href = a.href
  else
    if a.fireEvent('onclick', ev)
      window.location.href = a.href
  return

window.clone_event = (orig) ->
  e = undefined
  if document.dispatchEvent
    e = document.createEvent('MouseEvent')
    e.initMouseEvent orig.type, orig.canBubble, orig.cancelable, orig.view, orig.detail, orig.screenX, orig.screenY, orig.clientX, orig.clientY, orig.ctrlKey, orig.altKey, orig.shiftKey, orig.metaKey, orig.button, orig.relatedTarget
    Event.extend e
  else
    e = document.createEventObject(orig)
    Event.extend e

Object.extend String.prototype,
  subst: (subs) ->
    text = this
    for s of subs
      r = new RegExp('\\${' + s + '}', 'g')
      to = subs[s]
      if !to?
        to = ''
      text = text.replace(r, to)
    text
  createElement: ->
    container = document.createElement('div')
    container.innerHTML = this
    container.removeChild container.firstChild

window.createElement = (type, className, html) ->
  element = $(document.createElement(type))
  element.className = className
  element.innerHTML = html
  element

### Prototype calls onSuccess instead of onFailure when the user cancelled the AJAX
# request.  Fix that with a monkey patch, so we don't have to track changes inside
# prototype.js. 
###

Ajax.Request::successBase = Ajax.Request::success

Ajax.Request::success = ->
  try
    responses = @transport.getAllResponseHeaders()
    if !responses?
      return false
  catch e

    ### FF throws an exception if we call getAllResponseHeaders on a cancelled request. ###

    return false
  @successBase()

### Work around a Prototype bug; it discards exceptions instead of letting them fall back
# to the browser where they'll be logged. 
###

Ajax.Responders.register onException: (request, exception) ->

  ### Report the error here; don't wait for onerror to get it, since the exception
  # isn't passed to it so the stack trace is lost.  
  ###

  data = ''
  if request.url
    data += 'AJAX URL: ' + request.url + '\n'
  text = undefined
  length = undefined
  try
    params = request.parameters
    for key of params
      text = params[key]
      length = text.length
      if text.length > 1024
        text = text.slice(0, 1024) + '...'
      data += 'Parameter (' + length + '): ' + key + '=' + text + '\n'
  catch e
    data += 'Couldn\'t get response parameters: ' + e + '\n'
  try
    text = request.transport.responseText
    length = text.length
    if text.length > 1024
      text = text.slice(0, 1024) + '...'
    data += 'Response (' + length + '): ->' + text + '<-\n'
  catch e
    data += 'Couldn\'t get response text: ' + e + '\n'
  ReportError null, null, null, exception, data
  (->
    throw exception
    return
  ).defer()
  return

###
# In Firefox, exceptions thrown from event handlers tend to get lost.  Sometimes they
# trigger window.onerror, but not reliably.  Catch exceptions out of event handlers and
# throw them from a deferred context, so they'll make it up to the browser to be
# logged.
#
# This depends on bindAsEventListener actually only being used for event listeners,
# since it eats exceptions.
#
# Only do this in Firefox; not all browsers preserve the call stack in the exception,
# so this can lose information if used when it's not needed.
###

if Prototype.Browser.Gecko

  Function::bindAsEventListener = ->
    __method = this
    args = $A(arguments)
    object = args.shift()
    (event) ->
      try
        return __method.apply(object, [ event or window.event ].concat(args))
      catch exception
        (->
          throw exception
          return
        ).defer()
      return

window.onerror = (error, file, line) ->
  ReportError error, file, line, null
  return

###
# Return the values of list starting at idx and moving outwards.
#
# sort_array_by_distance([0,1,2,3,4,5,6,7,8,9], 5)
# [5,4,6,3,7,2,8,1,9,0]
###

window.sort_array_by_distance = (list, idx) ->
  ret = []
  ret.push list[idx]
  distance = 1
  loop
    length = ret.length
    if idx - distance >= 0
      ret.push list[idx - distance]
    if idx + distance < list.length
      ret.push list[idx + distance]
    if length == ret.length
      break
    ++distance
  ret

### Return the squared distance between two points. ###

window.distance_squared = (x1, y1, x2, y2) ->
  (x1 - x2) ** 2 + (y1 - y2) ** 2

### Return the size of the window. ###

window.getWindowSize = ->
  size = {}
  if window.innerWidth?
    size.width = window.innerWidth
    size.height = window.innerHeight
  else

    ### IE: ###

    size.width = document.documentElement.clientWidth
    size.height = document.documentElement.clientHeight
  size

### If 2d canvases are supported, return one.  Otherwise, return null. ###

window.create_canvas_2d = ->
  canvas = document.createElement('canvas')
  if canvas.getContext and canvas.getContext('2d')
    return canvas
  null

Prototype.Browser.AndroidWebKit = navigator.userAgent.indexOf('Android') != -1 and navigator.userAgent.indexOf('WebKit') != -1

### Some UI simply doesn't make sense on a touchscreen, and may need to be disabled or changed.
# It'd be nice if this could be done generically, but this is the best available so far ... 
###

Prototype.BrowserFeatures.Touchscreen = do ->

  ### iOS WebKit has window.Touch, a constructor for Touch events. ###

  if window.Touch
    return true
  # Mozilla/5.0 (Linux; U; Android 2.2; en-us; sdk Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1
  if navigator.userAgent.indexOf('Mobile Safari/') != -1
    return true
  # Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_2 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Mobile/8C134
  if navigator.userAgent.indexOf('Mobile/') != -1
    return true
  false

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
    debug 'Dragged off the bottom'
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

### When element is dragged, the document moves around it.  If scroll_element is true, the
# element should be positioned (eg. position: absolute), and the element itself will be
# scrolled. 
###

window.WindowDragElement = (element) ->
  @element = element
  @dragger = new DragElement(element,
    no_touch: true
    ondrag: @ondrag.bind(this)
    onstartdrag: @startdrag.bind(this))
  return

WindowDragElement::startdrag = ->
  @scroll_anchor_x = window.pageXOffset or document.documentElement.scrollLeft or document.body.scrollLeft
  @scroll_anchor_y = window.pageYOffset or document.documentElement.scrollTop or document.body.scrollTop
  return

WindowDragElement::ondrag = (e) ->
  scrollLeft = @scroll_anchor_x - (e.aX)
  scrollTop = @scroll_anchor_y - (e.aY)
  scrollTo scrollLeft, scrollTop
  return

### element should be positioned (eg. position: absolute).  When the element is dragged,
# scroll it around. 
###

window.WindowDragElementAbsolute = (element, ondrag_callback) ->
  @element = element
  @ondrag_callback = ondrag_callback
  @disabled = false
  @dragger = new DragElement(element,
    ondrag: @ondrag.bind(this)
    onstartdrag: @startdrag.bind(this))
  return

WindowDragElementAbsolute::set_disabled = (b) ->
  @disabled = b
  return

WindowDragElementAbsolute::startdrag = ->
  if @disabled
    return true

  ### cancel ###

  @scroll_anchor_x = @element.offsetLeft
  @scroll_anchor_y = @element.offsetTop
  false

WindowDragElementAbsolute::ondrag = (e) ->
  scrollLeft = @scroll_anchor_x + e.aX
  scrollTop = @scroll_anchor_y + e.aY

  ### Don't allow dragging the image off the screen; there'll be no way to
  # get it back. 
  ###

  window_size = getWindowSize()
  min_visible = Math.min(100, @element.offsetWidth)
  scrollLeft = Math.max(scrollLeft, min_visible - (@element.offsetWidth))
  scrollLeft = Math.min(scrollLeft, window_size.width - min_visible)
  min_visible = Math.min(100, @element.offsetHeight)
  scrollTop = Math.max(scrollTop, min_visible - (@element.offsetHeight))
  scrollTop = Math.min(scrollTop, window_size.height - min_visible)
  @element.setStyle
    left: scrollLeft + 'px'
    top: scrollTop + 'px'
  if @ondrag_callback
    @ondrag_callback()
  return

WindowDragElementAbsolute::destroy = ->
  @dragger.destroy()
  return

### Track the focused element, and store it in document.focusedElement.. ###

window.TrackFocus = ->
  document.focusedElement = null
  if document.addEventListener
    document.addEventListener 'focus', ((e) ->
      document.focusedElement = e.target
      return
    ).bindAsEventListener(this), true
  document.observe 'focusin', ((event) ->
    document.focusedElement = event.srcElement
    return
  ).bindAsEventListener(this)
  return

window.FormatError = (message, file, line, exc, info) ->
  report = ''
  report += 'Error: ' + message + '\n'
  if info?
    report += info
  report += 'UA: ' + window.navigator.userAgent + '\n'
  report += 'URL: ' + window.location.href + '\n'
  cookies = document.cookie
  cookies = cookies.replace(/(pass_hash)=[0-9a-f]{40}/, '$1=(removed)')
  try
    report += 'Cookies: ' + decodeURIComponent(cookies) + '\n'
  catch e
    report += 'Cookies (couldn\'t decode): ' + cookies + '\n'
  if 'localStorage' of window

    ### FF's localStorage is broken; we can't iterate over it.  Name the keys we use explicitly. ###

    keys = []
    try
      for storageKey of localStorage
        keys.push storageKey
    catch e
      keys = [
        'sample_urls'
        'sample_url_fifo'
        'tag_data'
        'tag_data_version'
        'recent_tags'
        'tag_data_format'
      ]
    i = 0
    while i < keys.length
      key = keys[i]
      try
        if !(key of localStorage)
          ++i
          continue
        data = localStorage[key]
        length = data.length
        if data.length > 512
          data = data.slice(0, 512)
        report += 'localStorage.' + key + ' (size: ' + length + '): ' + data + '\n'
      catch e
        report += '(ignored errors retrieving localStorage for ' + key + ': ' + e + ')\n'
      ++i
  if exc and exc.stack
    report += '\n' + exc.stack + '\n'
  if file
    report += 'File: ' + file
    if line?
      report += ' line ' + line + '\n'
  report

window.reported_error = false

window.ReportError = (message, file, line, exc, info) ->
  if navigator.userAgent.match(/.*MSIE [67]/)
    return

  ### Only attempt to report an error once per page load. ###

  if window.reported_error
    return
  window.reported_error = true

  ### Only report an error at most once per hour. ###

  if document.cookie.indexOf('reported_error=1') != -1
    return
  expiration = new Date
  expiration.setTime expiration.getTime() + 60 * 60 * 1000
  document.cookie = 'reported_error=1; path=/; expires=' + expiration.toGMTString()
  report = FormatError((if exc then exc.message else message), file, line, exc, info)
  try
    new (Ajax.Request)('/user/error.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters: report: report)
  catch e
    alert 'Error: ' + e
  return

window.LocalStorageDisabled = ->
  if !('localStorage' of window)
    return 'unsupported'
  cleared_storage = false
  loop
    try

      ### We can't just access a property to test it; that detects it being disabled in FF, but
      # not in Chrome. 
      ###

      localStorage.x = '1'
      if localStorage.x != '1'
        throw 'disabled'
      delete localStorage.x
      return null
    catch e

      ### If local storage is full, we may not be able to even run this test.  If that ever happens
      # something is wrong, so after a failure clear localStorage once and try again.  This call
      # may fail, too; ignore that and we'll catch the problem on the next try. 
      ###

      if !cleared_storage
        cleared_storage = true
        try
          localStorage.clear()
        catch e
        ++i
        ++i
        continue
      if navigator.userAgent.indexOf('Gecko/') != -1
        # If the user or an extension toggles about:config dom.storage.enabled, this happens:
        if e.message.indexOf('Security error') != -1
          return 'ff-disabled'

      ### Chrome unhelpfully reports QUOTA_EXCEEDED_ERR if local storage is disabled, which
      # means we can't easily detect it being disabled and show a tip to the user. 
      ###

      return 'error'
  return

### Chrome 10/WebKit braindamage; stop breaking things intentionally just to create
# busywork for everyone else: 
###

if !('URL' of window) and 'webkitURL' of window
  window.URL = window.webkitURL

### For Chrome 9: ###

if 'createObjectURL' of window and !('URL' of window)
  window.URL =
    createObjectURL: (blob) ->
      window.createObjectURL blob
    revokeObjectURL: (url) ->
      window.revokeObjectURL url
      return

### Allow CSS styles for WebKit. ###

if navigator.userAgent.indexOf('AppleWebKit/') != -1
  document.documentElement.className += ' webkit'
