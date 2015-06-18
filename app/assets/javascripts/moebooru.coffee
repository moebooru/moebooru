(($) ->
  window.Moebooru = {}
  window.Moe = $(Moebooru)

  Moebooru.path = (url) ->
    if PREFIX == '/' then url else PREFIX + url

  # XXX: Tested on chrome, mozilla, msie(9/10)
  # might or might not works in other browser

  Moebooru.dragElement = (el) ->
    win = $(window)
    doc = $(document)
    prevPos = []

    current = (x, y) ->
      windowOffset = [
        window.pageXOffset or document.documentElement.scrollLeft or document.body.scrollLeft
        window.pageYOffset or document.documentElement.scrollTop or document.body.scrollTop
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
      if e.which == 1

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
        return false
      return
    return

  return
) jQuery
