# This handler handles global keypress bindings, and fires viewer: events.
export default class InputHandler
  constructor: ->
    TrackFocus()

    # Keypresses are aggrevating:
    #
    # Opera can only stop key events from keypress, not keydown.
    #
    # Chrome only sends keydown for non-alpha keys, not keypress.
    #
    # In Firefox, keypress's keyCode value for non-alpha keys is always 0.
    #
    # Alpha keys can always be detected with keydown.  Don't use keypress; Opera only provides
    # charCode to that event, and it's affected by the caps state, which we don't want.
    #
    # Use OnKey for alpha key bindings.  For other keys, use keypress in Opera and FF and
    # keydown in other browsers.
    keypress_event_name = if window.opera or Prototype.Browser.Gecko then 'keypress' else 'keydown'
    document.on keypress_event_name, @document_keypress_event
    return

  handle_keypress: (e) ->
    key = e.charCode
    if !key
      key = e.keyCode

    # Opera
    if key == Event.KEY_ESC
      if document.focusedElement and document.focusedElement.blur and !document.focusedElement.hasClassName('no-blur-on-escape')
        document.focusedElement.blur()
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
