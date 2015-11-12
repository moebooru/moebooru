$ = jQuery
@Moebooru = {}
@Moe = $(Moebooru)

Moebooru.path = (url) ->
  if PREFIX == '/' then url else "#{PREFIX}#{url}"

# XXX: Tested on chrome, mozilla, msie(9/10)
# might or might not work in other browser
Moebooru.dragElement = (el) ->
  win = $(window)
  doc = $(document)
  prevPos = []

  current = (x, y) ->
    windowOffset = [
      window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft
      window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop
    ]
    offset = [
      windowOffset[0] + prevPos[0] - x
      windowOffset[1] + prevPos[1] - y
    ]
    prevPos[0] = x
    prevPos[1] = y
    offset

  el.on 'dragstart', ->
    false

  el.on 'mousedown', (e) ->
    return unless e.which == 1

    pageScroller = (e) ->
      scroll = current(e.clientX, e.clientY)
      scrollTo scroll[0], scroll[1]
      false

    el.css 'cursor', 'pointer'
    prevPos = [
      e.clientX
      e.clientY
    ]
    doc.on 'mousemove', pageScroller
    doc.one 'mouseup', (e) ->
      doc.off 'mousemove', pageScroller
      el.css 'cursor', 'auto'
      false
    false
