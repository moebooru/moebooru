keysDown = new Map
# Many browsers eat keyup events if focus is lost while the button
# is pressed. 
document.addEventListener 'blur', ->
  keysDown.clear()

window.OnKey = (key, options, press, release) ->
  options ?= {}
  element = options.Element ? document

  element.addEventListener 'keyup', (e) ->
    if e.keyCode != key
      return
    keysDown.set(e.keyCode, false)
    if release
      release e
    return
  element.addEventListener 'keydown', (e) ->
    if e.keyCode != key
      return
    if e.metaKey
      return
    if e.shiftKey != !!options.shiftKey
      return
    if e.altKey != !!options.altKey
      return
    if e.ctrlKey != !!options.ctrlKey
      return
    if !options.allowRepeat && keysDown.get(e.keyCode) == true
      return
    keysDown.set(e.keyCode, true)
    target = e.target
    if !options.AllowTextAreaFields && target.tagName == 'TEXTAREA'
      return
    if !options.AllowInputFields && target.tagName == 'INPUT'
      return
    if press? && !press(e)
      return
    e.preventDefault()
