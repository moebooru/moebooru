###
# The tag blob looks like this:
#
# 1:tagme 2:fixed
#
# where the initial number is the tag type, and a space after each tag is guaranteed, including
# after the final one.  Spaces and colons are disallowed in tags, so they don't need escaping.
# This can be searched quickly with regexes:
#
# ':tagme '   - whole tag match
# ':tag'      - tag prefix match
# ':t[^ ]*g'  - substring match
# ':[^ ]*me '  - suffix match
# ':[^ ]*t[^ ]*g[^ ]*m' - ordered character match
###

window.TagCompletionClass = ->

  ### Don't load the tag data out of localStorage until it's needed. ###

  @loading = false
  @loaded = false

  ### If the data format is out of date, clear it. ###

  current_version = '5'
  if localStorage.tag_data_format != current_version
    delete localStorage.tag_data
    delete localStorage.tag_data_version
    delete localStorage.recent_tags
    localStorage.tag_data_format = current_version

  ### Pull in recent tags.  This is entirely local data and not too big, so always load it. ###

  @recent_tags = localStorage.recent_tags or ''
  @load_data_complete_callbacks = []
  @rapid_backspaces_received = 0
  @updates_deferred = false
  return

TagCompletionClass::init = (current_version) ->
  if @loaded
    return
  @most_recent_tag_data_version = current_version
  return

###
# If cached data is available, load it.  If the cached data is out of date, run an
# update asynchronously.  Return true if data is available and tag completions may
# be done, whether or not the data is current.  Call onComplete when up-to-date tag
# data is available; if the current cached data is known to be current, it will be
# called before this function returns.
#
# If this is called multiple times before the tag load completes, the data will only be loaded
# once, but all callbacks will be called.
###
TagCompletionClass::load_data = (onComplete) ->
  # If we're already fully loaded, just run the callback and return.
  if @loaded
    onComplete?()
    return @tag_data?

  # Add the callback to the list.
  if onComplete?
    @load_data_complete_callbacks.push onComplete

  # If we're already loading, let the existing request finish; it'll run the callback.
  if @loading
    return @tag_data?

  @loading = true

  complete = =>
    @loading = false
    @loaded = true

    # Now that we have the tag types loaded, update any tag types that we have loaded.
    @update_tag_types()

    callbacks = @load_data_complete_callbacks
    @load_data_complete_callbacks = []
    callback() for callback in callbacks

  # If we have data available, load it.
  if localStorage.tag_data?
    @tag_data = localStorage.tag_data

    # If we've been told the current tag data revision and we're already on it, or if we havn't
    # been told the revision at all, use the data we have. 
    if !@most_recent_tag_data_version? localStorage.tag_data_version == @most_recent_tag_data_version
      # console.log("Already on most recent tag data version");
      complete()
      return @tag_data?

  # Request the tag data from the server.  Tell the server the data version we already
  # have. 
  jQuery
    .ajax
      url: "/tag/summary.json"
      data:
        version: localStorage.tag_data_version
      dataType: "json"
    .done (json) =>
      if json.unchanged
        # If unchanged is true, tag_data_version is already current; this means we weren't told
        # the current data revision to start with but we're already up to date. 
        # console.log("Tag data unchanged")
        @tag_data = localStorage.tag_data
      else
        # We received new tag data; save it.
        # console.log("Storing new tag data")
        @tag_data = json.data
        localStorage.tag_data = @tag_data
        localStorage.tag_data_version = json.version
      complete()

  @tag_data?

### When form is submitted, call add_recent_tags_from_update for the given tags and old_tags
# fields. 
###

TagCompletionClass::observe_tag_changes_on_submit = (form, tags_field, old_tags_field) ->
  form.on 'submit', (e) ->
    TagCompletion.add_recent_tags_from_update tags_field.value, old_tags_field?.value

### From a tag string, eg. "1`tagme`alias`alias2`", retrieve the tag name "tagme". ###

get_tag_from_string = (tag_string) ->
  m = tag_string.match(/\d+`([^`]*)`.*/)
  if !m
    throw 'Unparsable cached tag: \'' + tag_string + '\''
  m[1]

###
# Like string.split, but rather than each item of data being separated by the separator,
# each item of data ends in the separator; that is, the final item is followed by the
# separator.
#
# "a b c " -> ["a", "b", "c"].
#
# If the final item doesn't end in the separator, throw an exception.
#
###

split_data = (str, separator) ->
  result = str.split(separator)
  if result.length != 0
    if result[result.length - 1] != ''
      throw 'String doesn\'t end in separator'
    result.pop()
  result

join_data = (items, separator) ->
  if items.length == 0
    return ''
  items.join(separator) + separator

### Update the cached types of all known tags in tag_data and recent_tags. ###

TagCompletionClass::update_tag_types_for_list = (tags, allow_add) ->
  tag_map = {}

  ### Make a mapping of tags to indexes. ###

  split_tags = split_data(tags, ' ')
  idx = 0
  split_tags.each (tag) ->
    if tag == ''
      return
    tag_name = get_tag_from_string(tag)
    tag_map[tag_name] = idx
    ++idx
    return

  ###
  # For each known tag type, mark the type in the tag cache.  We receive this info when
  # we download the tag types, so this is just updating any changes.
  #
  # This is set up to iterate only over known types, and not over the entire list of
  # tags, so when we have a lot of tags we minimize the amount of work we have to do
  # on every tag.
  ###

  Post.tag_types.each (tag_and_type) ->
    tag = tag_and_type[0]
    tag_type = tag_and_type[1]
    tag_type_idx = Post.tag_type_names.indexOf(tag_type)
    if tag_type_idx == -1
      throw 'Unknown tag type ' + tag_type
    if !(tag of tag_map)

      ### This tag is known in Post.tag_types, but isn't a known tag.  If allow_add is true,
      # add it to the end.  This is for updating new tags that have shown up on the server,
      # not for adding new recent tags. 
      ###

      if allow_add
        tag_string = tag_type_idx + '`' + tag + '`'
        split_tags.push tag_string
    else

      ### This is a known tag; this is the usual case.  Parse out the complete tag from the
      # original string, and update the tag type index. 
      ###

      tag_idx = tag_map[tag]
      existing_tag = split_tags[tag_idx]
      m = existing_tag.match(/\d+(`.*)/)
      new_tag_string = tag_type_idx + m[1]
      split_tags[tag_idx] = new_tag_string
    return
  join_data split_tags, ' '

TagCompletionClass::update_tag_types = ->

  ### This function is always called, because we receive tag type data for most pages.
  # Only actually update tag types if the tag data is already loaded. 
  ###

  if !@loaded
    return

  ### Update both tag_data and recent_tags; only add new entries to tag_data. ###

  @tag_data = @update_tag_types_for_list(@tag_data, true)
  localStorage.tag_data = @tag_data
  @recent_tags = @update_tag_types_for_list(@recent_tags, false)
  localStorage.recent_tags = @recent_tags
  return

TagCompletionClass::create_tag_search_regex = (tag, options) ->

  ### Split the tag by character. ###

  letters = tag.split('')

  ###
  # We can do a few search methods:
  #
  # 1: Ordinary prefix search.
  # 2: Name search. "aaa_bbb" -> "aaa*_bbb*|bbb*_aaa*".
  # 3: Contents search; "tgm" -> "t*g*m*" -> "tagme".  The first character is still always
  # matched exactly.
  #
  # Avoid running multiple expressions.  Instead, combine these into a single one, then run
  # each part on the results to determine which type of result it is.  Always show prefix and
  # name results before contents results.
  ###

  regex_parts = []

  ### Allow basic word prefix matches.  "tag" matches at the beginning of any word
  # in a tag, eg. both "tagme" and "dont_tagme". 
  ###

  ### Add the regex for ordinary prefix matches. ###

  s = '(([^`]*_)?'
  letters.each (letter) ->
    escaped_letter = RegExp.escape(letter)
    s += escaped_letter
    return
  s += ')'
  regex_parts.push s

  ### Allow "fir_las" to match both "first_last" and "last_first". ###

  if tag.indexOf('_') != -1
    first = tag.split('_', 1)[0]
    last = tag.slice(first.length + 1)
    first = RegExp.escape(first)
    last = RegExp.escape(last)
    s = '('
    s += '(' + first + '[^`]*_' + last + ')'
    s += '|'
    s += '(' + last + '[^`]*_' + first + ')'
    s += ')'
    regex_parts.push s

  ### Allow "tgm" to match "tagme".  If top_results_only is set, we only want primary results,
  # so omit this match. 
  ###

  if !options.top_results_only
    s = '('
    letters.each (letter) ->
      escaped_letter = RegExp.escape(letter)
      s += escaped_letter
      s += '[^`]*'
      return
    s += ')'
    regex_parts.push s

  ### The space is included in the result, so the result tags can be matched with the
  # same regexes, for in reorder_search_results.
  #
  # (\d)+  match the alias ID                      1`
  # [^ ]*: start at the beginning of any alias     1`foo`bar`
  # ... match ...
  # [^`]*` all matches are prefix matches          1`foo`bar`tagme`
  # [^ ]*  match any remaining aliases             1`foo`bar`tagme`tag_me`
  ###

  regex_string = regex_parts.join('|')
  regex_string = '(\\d+)[^ ]*`(' + regex_string + ')[^`]*`[^ ]* '
  new RegExp(regex_string, if options.global then 'g' else '')

TagCompletionClass::retrieve_tag_search = (re, source, options) ->
  results = []
  max_results = 10
  if options.max_results?
    max_results = options.max_results
  while results.length < max_results
    m = re.exec(source)
    if !m
      break
    tag = m[0]

    ### Ignore this tag.  We need a better way to blackhole tags. ###

    if tag.indexOf(':deletethistag:') != -1
      continue
    if results.indexOf(tag) == -1
      results.push tag
  results

### Mark a tag as recently used.  Recently used tags are matched before other tags. ###

TagCompletionClass::add_recent_tag = (tag) ->

  ### Don't add tags that will make the data unparsable. ###

  if tag.indexOf(' ') != -1 or tag.indexOf('`') != -1
    throw 'Invalid recent tag: ' + tag
  @remove_recent_tag tag

  ### Look up the tag type if we know it. ###

  tag_type = Post.tag_types.get(tag) or 'general'
  tag_type_idx = Post.tag_type_names.indexOf(tag_type)

  ### We should know all tag types. ###

  if tag_type_idx == -1
    throw 'Unknown tag type: ' + tag_type

  ### Add the tag to the front.  Always append a space, not just between entries. ###

  tag_entry = tag_type_idx + '`' + tag + '` '
  @recent_tags = tag_entry + @recent_tags

  ### If the recent tags list is too big, remove data from the end. ###

  max_recent_tags_size = 1024 * 16
  if @recent_tags.length > max_recent_tags_size * 10 / 9

    ### Be sure to leave the trailing space in place. ###

    purge_at = @recent_tags.indexOf(' ', max_recent_tags_size)
    if purge_at != -1
      @recent_tags = @recent_tags.slice(0, purge_at + 1)
  localStorage.recent_tags = @recent_tags
  return

### Remove the tag from the recent tag list. ###

TagCompletionClass::remove_recent_tag = (tag) ->
  escaped_tag = RegExp.escape(tag)
  re = new RegExp('\\d`' + escaped_tag + '` ', 'g')
  @recent_tags = @recent_tags.replace(re, '')
  localStorage.recent_tags = @recent_tags
  return

### Add as recent tags all tags which are in tags and not in old_tags.  If this is from an
# edit form, old_tags must be the hidden old_tags value in the edit form; if this is
# from a search form, old_tags must be null. 
###

TagCompletionClass::add_recent_tags_from_update = (tags, old_tags) ->
  tags = tags.split(' ')
  if old_tags?
    old_tags = old_tags.split(' ')
  tags.each ((tag) ->

    ### Ignore invalid tags. ###

    if tag.indexOf('`') != -1
      return

    ### Ignore rating shortcuts. ###

    if 'sqe'.indexOf(tag) != -1
      return

    ### Ignore tags that the user didn't just add. ###

    if old_tags and old_tags.indexOf(tag) != -1
      return

    ###
    # We may be adding tags from an edit form or a search form.  If we're on an edit
    # form, old_tags is set; if we're on a search form, old_tags is null.
    #
    # If we're on a search form, ignore non-metatags that don't exist in tag_data.  This
    # will just allow adding typos to recent tag data.
    #
    # If we're on an edit form, allow these completely new tags to be added, since the
    # edit form is going to create them.
    ###

    if (!old_tags?) and tag.indexOf(':') == -1
      if @tag_data.indexOf('`' + tag + '`') == -1
        return
    @add_recent_tag tag
    return
  ).bind(this)
  return

###
# Contents matches (t*g*m -> tagme) are lower priority than other results.  Within
# each search type (recent and main), sort them to the bottom.
###

TagCompletionClass::reorder_search_results = (tag, results) ->
  re = @create_tag_search_regex(tag,
    top_results_only: true
    global: false)
  top_results = []
  bottom_results = []
  results.each (tag) ->
    if re.test(tag)
      top_results.push tag
    else
      bottom_results.push tag
    return
  top_results.concat bottom_results

###
# Return an array of completions for a tag.  Tag types of returned tags will be
# registered in Post.tag_types, if necessary.
#
# options = {
#   max_results: 10
# }
#
# [["tag1", "tag2", "tag3"], 1]
#
# The value 1 is the number of results from the beginning which come from recent_tags,
# rather than tag_data.
###

TagCompletionClass::complete_tag = (tag, options) ->
  if !@tag_data?
    throw 'Tag data isn\'t loaded'
  if !options?
    options = {}
  if tag == ''
    return [
      []
      0
    ]

  ### Make a list of all results; this will be ordered recent tags first, other tags
  # sorted by tag count.  Request more results than we need, since we'll reorder
  # them below before cutting it off. 
  ###

  re = @create_tag_search_regex(tag, global: true)
  recent_results = @retrieve_tag_search(re, @recent_tags, max_results: 100)
  main_results = @retrieve_tag_search(re, @tag_data, max_results: 100)
  recent_results = @reorder_search_results(tag, recent_results)
  main_results = @reorder_search_results(tag, main_results)
  recent_result_count = recent_results.length
  results = recent_results.concat(main_results)

  ### Hack: if the search is one of the ratings shortcuts, put that at the top, even though
  # it's not a real tag. 
  ###

  if 'sqe'.indexOf(tag) != -1
    results.unshift '0`' + tag + '` '
  results = results.slice(0, if options.max_results? then options.max_results else 10)
  recent_result_count = Math.min(results.length, recent_result_count)

  ### Strip the "1`" tag type prefix off of each result. ###

  final_results = []
  tag_types = {}
  final_aliases = []
  results.each (tag) ->
    m = tag.match(/(\d+)`([^`]*)`(([^ ]*)`)? /)
    if !m
      ReportError 'Unparsable cached tag: \'' + tag + '\'', null, null, null, null
      throw 'Unparsable cached tag: \'' + tag + '\''
    tag = m[2]
    tag_type = Post.tag_type_names[m[1]]
    aliases = m[4]
    if m[4]
      aliases = aliases.split('`')
    else
      aliases = []
    tag_types[tag] = tag_type
    if final_results.indexOf(tag) == -1
      final_results.push tag
      final_aliases.push aliases
    return

  ### Register tag types of results with Post. ###

  Post.register_tags tag_types, true
  [
    final_results
    recent_result_count
    final_aliases
  ]

### This is only supported if the browser supports localStorage.  Also disable this if
# addEventListener is missing; IE has various problems that aren't worth fixing. 
###

if !LocalStorageDisabled() and 'addEventListener' of document
  window.TagCompletion = new TagCompletionClass
else
  window.TagCompletion = null

window.TagCompletionBox = (input_field) ->
  @input_field = input_field
  @update = @update.bind(this)
  @last_value = @input_field.value

  ### Disable browser autocomplete. ###

  @input_field.setAttribute 'autocomplete', 'off'
  html = '<div class="tag-completion-box"><ul class="color-tag-types"></ul></div>'
  div = html.createElement()
  div.tabindex = -1
  document.body.appendChild div
  @completion_box = div
  document.on 'mousedown', ((event) ->
    if event.target.isParentNode(@input_field) or event.target.isParentNode(@completion_box)
      return
    @hide()
    return
  ).bindAsEventListener(this)
  @input_field.on 'mousedown', @input_mouse.bindAsEventListener(this)
  @input_field.on 'mouseup', @input_mouse.bindAsEventListener(this)
  @input_field.parentNode.addEventListener 'keydown', @input_keydown.bindAsEventListener(this), true
  # need to use addEventListener for this since Prototype is broken
  @input_field.on 'keypress', @input_keypress.bindAsEventListener(this)
  @completion_box.on 'mouseover', '.completed-tag', ((event, element) ->
    @focus_element element
    return
  ).bind(this)
  @completion_box.on 'click', 'li', @click_result.bind(this)
  @hide()
  return

TagCompletionBox::input_mouse = (event) ->
  @update.defer()
  return

TagCompletionBox::input_keydown = (event) ->
  if event.target != @input_field
    return

  ### Handle backspaces even when hidden. ###

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
    if @backspace_timeout
      clearTimeout @backspace_timeout
    @backspace_timeout = setTimeout((->
      @rapid_backspaces_received = 0
      return
    ).bind(this), 100)
    if @rapid_backspaces_received > 1
      @updates_deferred = true
      if @defer_timeout?
        clearTimeout @defer_timeout
      @defer_timeout = setTimeout((->
        @updates_deferred = false
        @update()
        return
      ).bind(this), 100)
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

TagCompletionBox::focus_element = (element) ->
  if !element?
    throw 'Can\'t select no element'
  previous = @completion_box.down('.focused')
  if previous
    previous.removeClassName 'focused'
  if element
    element.addClassName 'focused'
  return

TagCompletionBox::select_next = (next) ->
  focused = @completion_box.down('.focused')
  siblings = if next then focused.nextSiblings() else focused.previousSiblings()
  new_focus = Prototype.Selector.find(siblings, '.completed-tag', 0)
  if !new_focus?
    new_focus = @completion_box.down(if next then '.completed-tag' else '.completed-tag:last-child')
  @focus_element new_focus
  return

TagCompletionBox::show = ->
  @shown = true
  offset = @input_field.cumulativeOffset()
  @completion_box.style.top = offset.top + @input_field.offsetHeight + 'px'
  @completion_box.style.left = offset.left + 'px'
  @completion_box.style.minWidth = @input_field.offsetWidth + 'px'
  return

TagCompletionBox::hide = ->
  @shown = false
  @current_tag = null
  @completion_box.hide()
  return

TagCompletionBox::click_result = (event, element) ->
  event.stop()
  if event.target.hasClassName('remove-recent-tag')
    TagCompletion.remove_recent_tag element.result_tag
    @update true
    return
  @set_current_word element.result_tag
  return

TagCompletionBox::get_input_word_offset = (field) ->
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

### Replace the tag under the cursor. ###

TagCompletionBox::set_current_word = (tag) ->
  offset = @get_input_word_offset(@input_field)
  text = @input_field.value
  before = text.substr(0, offset.start)
  after = text.substr(offset.end)
  tag_text = tag

  ### If there's only whitespace after the tag, remove it.  We'll add a single space
  # below. 
  ###

  if after.match(/^ +$/)
    after = ''

  ### If we're at the end of the string, or if there's only whitespace after the tag,
  # insert a space after the tag. 
  ###

  if after == ''
    tag_text += ' '
  @input_field.value = before + tag_text + after

  ### Position the cursor at the end of the tag we just inserted. ###

  cursor_position = before.length + tag_text.length
  @input_field.selectionStart = @input_field.selectionEnd = cursor_position
  TagCompletion.add_recent_tag tag
  @hide()
  return

TagCompletionBox::update = (force) ->
  if @updates_deferred and !force
    return

  ### If the tag data hasn't been loaded, run the load and rerun the update when it
  # completes. 
  ###

  if !TagCompletion.tag_data?

    ### If this returns true, we'll display with the data we have now.  If this happens,
    # don't update during the callback; it's bad UI to be changing the list out from
    # under the user at a seemingly random time. 
    ###

    data_available = TagCompletion.load_data((->
      if data_available
        return

      ### After the load completes, force an update, even though the tag we're completing
      # hasn't changed; the tag data may have. 
      ###

      @current_tag = null
      @update()
      return
    ).bind(this))
    if !data_available
      return

  ### Figure out the tag the cursor is on. ###

  offset = @get_input_word_offset(@input_field)
  tag = @input_field.value.substr(offset.start, offset.end - (offset.start))
  if tag == @current_tag and !force
    return
  @hide()

  ### Don't show the autocomplete unless the contents actually change, so we can still
  # navigate multiline tag input boxes with the arrow keys. 
  ###

  if @last_value == @input_field.value and !force
    return
  @last_value = @input_field.value
  @current_tag = tag

  ### Don't display if the input field itself is hidden. ###

  if !@input_field.recursivelyVisible()
    return
  tags_and_recent_count = TagCompletion.complete_tag(tag)
  tags = tags_and_recent_count[0]
  tag_aliases = tags_and_recent_count[2]
  recent_result_count = tags_and_recent_count[1]
  if tags.length == 0
    return
  if tags.length == 1 and tags[0] == tag

    ### There's only one result, and it's the tag already in the field; don't
    # show the list. 
    ###

    return
  @show()

  ### Clear any old results. ###

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

    ### If we have any aliases, show the first one. ###

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

  ### Focus the first item. ###

  @focus_element @completion_box.down('.completed-tag')
  return

TagCompletionBox::input_keypress = (event) ->
  @update.defer()
  return

### If tag completion isn't supported, disable TagCompletionBox. ###

if TagCompletion == null or !('addEventListener' of document)

  window.TagCompletionBox = ->
