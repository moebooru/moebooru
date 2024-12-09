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

  # Don't allow dragging the image off the screen; there'll be no way to
  # get it back. 
  min_visible = Math.min(100, @element.offsetWidth)
  scrollLeft = Math.max(scrollLeft, min_visible - (@element.offsetWidth))
  scrollLeft = Math.min(scrollLeft, window.innerWidth - min_visible)
  min_visible = Math.min(100, @element.offsetHeight)
  scrollTop = Math.max(scrollTop, min_visible - (@element.offsetHeight))
  scrollTop = Math.min(scrollTop, window.innerHeight - min_visible)
  @element.setStyle
    left: scrollLeft + 'px'
    top: scrollTop + 'px'
  if @ondrag_callback
    @ondrag_callback()
  return

WindowDragElementAbsolute::destroy = ->
  @dragger.destroy()
  return
