import DragElement from 'src/classes/drag_element'

export default class SwipeHandler
  constructor: (element) ->
    @element = element
    @dragger = new DragElement(element, ondrag: @ondrag, onstartdrag: @startdrag)

  startdrag: =>
    @swiped_horizontal = false
    @swiped_vertical = false
    return

  ondrag: (e) =>
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

  destroy: ->
    @dragger.destroy()
    return
