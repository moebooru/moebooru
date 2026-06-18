Object.extend Element.Methods,
  showBase: Element.show
  show: (element, visible) ->
    if visible or !visible?
      $(element).showBase()
    else
      $(element).hide()
Element.addMethods()
