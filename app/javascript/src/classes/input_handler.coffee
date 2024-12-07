# This handler handles global keypress bindings, and fires viewer: events.
export default class InputHandler
  constructor: ->
    document.on 'keydown', @document_keypress_event


  handle_keypress: (e) ->
    key = e.charCode
    if !key
      key = e.keyCode

    # Opera
    if key == Event.KEY_ESC
      activeElement = document.activeElement
      if activeElement != null && activeElement.blur != null && !activeElement.classList.contains('no-blur-on-escape')
        activeElement.blur()
        return true
    target = e.target
    if target.tagName == 'INPUT' or target.tagName == 'TEXTAREA'
      return false
    if key == 63
      console.debug 'help key'
      document.fire 'viewer:show-help'
      return true
    if e.shiftKey or e.altKey or e.ctrlKey or e.metaKey
      return false
    grave_keycode = if Prototype.Browser.WebKit then 192 else 96
    if key == 32
      document.fire 'viewer:set-thumb-bar', toggle: true
    else if key == 49
      document.fire 'viewer:vote', score: 1
    else if key == 50
      document.fire 'viewer:vote', score: 2
    else if key == 51
      document.fire 'viewer:vote', score: 3
    else if key == grave_keycode
      document.fire 'viewer:vote', score: 0
    else if key == 65 or key == 97
      document.fire 'viewer:show-next-post', prev: true
    else if key == 69 or key == 101
      document.fire 'viewer:edit-post'
    else if key == 83 or key == 115
      document.fire 'viewer:show-next-post', prev: false
    else if key == 70 or key == 102
      document.fire 'viewer:focus-tag-box'
    else if key == 86 or key == 118
      document.fire 'viewer:view-large-toggle'
    else if key == Event.KEY_PAGEUP
      document.fire 'viewer:show-next-post', prev: true
    else if key == Event.KEY_PAGEDOWN
      document.fire 'viewer:show-next-post', prev: false
    else if key == Event.KEY_LEFT
      document.fire 'viewer:scroll', left: true
    else if key == Event.KEY_RIGHT
      document.fire 'viewer:scroll', left: false
    else
      return false
    true

  document_keypress_event: (e) =>
    #alert(e.charCode + ", " + e.keyCode);
    if @handle_keypress(e)
      e.stop()
    return
