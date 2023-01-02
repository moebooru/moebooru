export default class TagCompletionBox
  constructor: (input_field) ->
    @input_field = input_field
    @last_value = @input_field.value

    # Disable browser autocomplete.
    @input_field.setAttribute 'autocomplete', 'off'
    html = '<div class="tag-completion-box"><ul class="color-tag-types"></ul></div>'
    div = html.createElement()
    div.tabindex = -1
    document.body.appendChild div
    @completion_box = div
    document.on 'mousedown', (event) =>
      if event.target.isParentNode(@input_field) or event.target.isParentNode(@completion_box)
        return
      @hide()
      return

    @input_field.on 'mousedown', @input_mouse
    @input_field.on 'mouseup', @input_mouse
    @input_field.parentNode.addEventListener 'keydown', @input_keydown, true
    # need to use addEventListener for this since Prototype is broken
    @completion_box.on 'mouseover', '.completed-tag', (event, element) =>
      @focus_element element
      return
    @completion_box.on 'click', 'li', @click_result
    @hide()

  input_mouse: (event) =>
    @update.defer()
    return

  input_keydown: (event) =>
    if event.target != @input_field
      return

    # Handle backspaces even when hidden.
    if event.keyCode == Event.KEY_BACKSPACE
      ###
      # If the user holds down backspace to delete tags, don't spend time updating the
      # autocomplete; if it's too slow it may slow down the input.  However, we don't
      # want to always delay autocomplete on backspace; it looks unresponsive.
      #
      # Count the number of backspaces we receive less than 100ms apart.  Defer updates
      # after we receive two or more in rapid succession, so we'll defer when backspace
      # is held down but not when being depressed.
      #
      # Note that this is done this way rather than by tracking the pressed state with
      # keydown/keyup, because this way we don't need to deal with lost keyup events if
      # focus is lost while the key is pressed.  There's no way to become desynced this way.
      ###
      ++@rapid_backspaces_received
      clearTimeout @backspace_timeout
      backspaceTimeoutFn = => @rapid_backspaces_received = 0
      @backspace_timeout = setTimeout(backspaceTimeoutFn, 100)
      if @rapid_backspaces_received > 1
        @updates_deferred = true
        clearTimeout @defer_timeout
        deferTimeoutFn = =>
          @updates_deferred = false
          @update()
        @defer_timeout = setTimeout(deferTimeoutFn, 100)
    if !@shown
      @update.defer()
      return
    if event.keyCode == Event.KEY_DOWN
      event.stop()
      @select_next true
    else if event.keyCode == Event.KEY_UP
      event.stop()
      @select_next false
    else if event.keyCode == Event.KEY_ESC
      event.stop()
      @hide()
    else if event.keyCode == Event.KEY_RETURN
      focused = @completion_box.down('.focused')
      if focused
        event.stop()
        @set_current_word focused.result_tag
      else
        @hide()
    else
      @update.defer()
    return

  focus_element: (element) =>
    if !element?
      throw 'Can\'t select no element'
    previous = @completion_box.down('.focused')
    if previous
      previous.removeClassName 'focused'
    if element
      element.addClassName 'focused'
    return

  select_next: (next) =>
    focused = @completion_box.down('.focused')
    siblings = if next then focused.nextSiblings() else focused.previousSiblings()
    new_focus = Prototype.Selector.find(siblings, '.completed-tag', 0)
    new_focus ?= @completion_box.down(if next then '.completed-tag' else '.completed-tag:last-child')
    @focus_element new_focus
    return

  show: =>
    @shown = true
    offset = @input_field.cumulativeOffset()
    @completion_box.style.top = offset.top + @input_field.offsetHeight + 'px'
    @completion_box.style.left = offset.left + 'px'
    @completion_box.style.minWidth = @input_field.offsetWidth + 'px'
    return

  hide: =>
    @shown = false
    @current_tag = null
    @completion_box.hide()
    return

  click_result: (event, element) =>
    event.stop()
    if event.target.hasClassName('remove-recent-tag')
      TagCompletion.remove_recent_tag element.result_tag
      @update true
      return
    @set_current_word element.result_tag
    return

  get_input_word_offset: (field) =>
    text = field.value
    start_idx = text.lastIndexOf(' ', field.selectionStart - 1)
    if start_idx == -1
      start_idx = 0
    else
      ++start_idx
    # skip the space itself
    end_idx = text.indexOf(' ', field.selectionStart)
    if end_idx == -1
      end_idx = text.length
    {
      start: start_idx
      end: end_idx
    }

  # Replace the tag under the cursor.
  set_current_word: (tag) =>
    offset = @get_input_word_offset(@input_field)
    text = @input_field.value
    before = text.substr(0, offset.start)
    after = text.substr(offset.end)
    tag_text = tag

    # If there's only whitespace after the tag, remove it.  We'll add a single space
    # below.
    if after.match(/^ +$/)
      after = ''

    # If we're at the end of the string, or if there's only whitespace after the tag,
    # insert a space after the tag.
    if after == ''
      tag_text += ' '
    @input_field.value = before + tag_text + after

    # Position the cursor at the end of the tag we just inserted.
    cursor_position = before.length + tag_text.length
    @input_field.selectionStart = @input_field.selectionEnd = cursor_position
    TagCompletion.add_recent_tag tag
    @hide()
    return

  update: (force) =>
    if @updates_deferred and !force
      return

    # If the tag data hasn't been loaded, run the load and rerun the update when it
    # completes.
    if !TagCompletion.tag_data?
      # If this returns true, we'll display with the data we have now.  If this happens,
      # don't update during the callback; it's bad UI to be changing the list out from
      # under the user at a seemingly random time.
      data_available = TagCompletion.load_data =>
        if data_available
          return

        # After the load completes, force an update, even though the tag we're completing
        # hasn't changed; the tag data may have.
        @current_tag = null
        @update()
        return
      if !data_available
        return

    # Figure out the tag the cursor is on.
    offset = @get_input_word_offset(@input_field)
    tag = @input_field.value.substr(offset.start, offset.end - (offset.start))
    if tag == @current_tag and !force
      return
    @hide()

    # Don't show the autocomplete unless the contents actually change, so we can still
    # navigate multiline tag input boxes with the arrow keys.
    if @last_value == @input_field.value and !force
      return
    @last_value = @input_field.value
    @current_tag = tag

    # Don't display if the input field itself is hidden.
    if !@input_field.recursivelyVisible()
      return
    tags_and_recent_count = TagCompletion.complete_tag(tag)
    tags = tags_and_recent_count[0]
    tag_aliases = tags_and_recent_count[2]
    recent_result_count = tags_and_recent_count[1]
    if tags.length == 0
      return
    if tags.length == 1 and tags[0] == tag
      # There's only one result, and it's the tag already in the field; don't
      # show the list.
      return
    @show()

    # Clear any old results.
    ul = @completion_box.down('UL')
    @completion_box.hide()
    while ul.firstChild
      ul.removeChild ul.firstChild
    i = 0
    while i < tags.length
      tag = tags[i]
      li = document.createElement('LI')
      li.className = 'completed-tag'
      li.setTextContent tag
      ul.appendChild li

      # If we have any aliases, show the first one.
      aliases = tag_aliases[i]
      if aliases.length > 0
        span = document.createElement('span')
        span.className = 'completed-tag-alias'
        span.setTextContent aliases[0]
        li.appendChild span
      tag_type = Post.tag_types.get(tag)
      li.className += ' tag-type-' + tag_type
      if i < recent_result_count
        li.className += ' recent-tag'
        h = '<a class=\'remove-recent-tag\' href=\'#\'>X</a>\''
        li.appendChild h.createElement()
      li.result_tag = tag
      ++i
    @completion_box.show()

    # Focus the first item.
    @focus_element @completion_box.down('.completed-tag')
    return
