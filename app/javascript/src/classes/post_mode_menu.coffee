get_style_for_mode = (s) ->
  if s == 'view'
    { background: '' }
  else if s == 'edit'
    { background: '#3A3' }
  else if s == 'rating-q'
    { background: '#AAA' }
  else if s == 'rating-s'
    { background: '#6F6' }
  else if s == 'rating-e'
    { background: '#F66' }
  else if s == 'vote'
    { background: '#FAA' }
  else if s == 'lock-rating'
    { background: '#AA3' }
  else if s == 'lock-note'
    { background: '#3AA' }
  else if s == 'approve'
    { background: '#26A' }
  else if s == 'flag'
    { background: '#F66' }
  else if s == 'add-to-pool'
    { background: '#26A' }
  else if s == 'apply-tag-script'
    { background: '#A3A' }
  else if s == 'reparent-quick'
    { background: '#CCA' }
  else if s == 'remove-from-pool'
    { background: '#CCA' }
  else if s == 'reparent'
    { background: '#0C0' }
  else if s == 'dupe'
    { background: '#0C0' }
  else
    { background: '#AFA' }

export default class PostModeMenu
  constructor: ->
    @dragging_active = false
    @dragging_from_post = null
    @dragging_hash = null
    @dragging_list = null
    @mode = 'view'

  init: (pool_id) ->
    # If pool_id isn't null, it's the pool that we're currently searching for.
    @pool_id = pool_id
    color_element = $('mode-box')
    @original_style = border: color_element.getStyle('border')
    if Cookie.get('mode') == ''
      Cookie.put 'mode', 'view'
      $('mode').value = 'view'
    else
      $('mode').value = Cookie.get('mode')
    @vote_score = Cookie.get('vote')
    if @vote_score == ''
      @vote_score = 1
      Cookie.put 'vote', @vote_score
    else
      @vote_score = +@vote_score
    Post.posts.each (p) =>
      post_id = p[0]
      post = p[1]
      span = $('p' + post.id)
      if !span?
        return

      # Use post_id here, not post, since the post object can be replaced later after updates.
      span.down('A').observe 'click', (e) =>
        @click e, post_id
        return
      span.down('A').observe 'mousedown', (e) =>
        @post_mousedown e, post_id
        return
      span.down('A').observe 'mouseover', (e) =>
        @post_mouseover e, post_id
        return
      span.down('A').observe 'mouseout', (e) =>
        @post_mouseout e, post_id
        return
      span.down('A').observe 'mouseup', (e) =>
        @post_mouseup e, post_id
        return
      return
    document.observe 'mouseup', (e) =>
      @post_mouseup e, null
      return
    Event.observe window, 'pagehide', (e) =>
      @post_end_drag()
      return
    @change()
    return
  set_vote: (score) ->
    @vote_score = score
    Cookie.put 'vote', @vote_score
    Post.update_vote_widget 'vote-menu', @vote_score
    return
  change: ->
    if !$('mode')
      return
    s = $F('mode')
    Cookie.put 'mode', s, 7
    @mode = s
    if s != 'edit'
      $('quick-edit').hide()
    if s != 'apply-tag-script'
      $('edit-tag-script').hide()
      Post.reset_tag_script_applied()
    if s == 'vote'
      Post.update_vote_widget 'vote-menu', @vote_score
      $('vote-score').show()
    else if s == 'apply-tag-script'
      $('edit-tag-script').show()
      $('edit-tag-script').focus()
    return
  click: (event, post_id) ->
    s = $('mode')
    if !s
      return
    if s.value == 'view'
      return true
    if s.value == 'edit'
      post_quick_edit.show post_id
    else if s.value == 'vote'
      Post.vote post_id, @vote_score
    else if s.value == 'rating-q'
      Post.update_batch [ {
        id: post_id
        rating: 'questionable'
      } ]
    else if s.value == 'rating-s'
      Post.update_batch [ {
        id: post_id
        rating: 'safe'
      } ]
    else if s.value == 'rating-e'
      Post.update_batch [ {
        id: post_id
        rating: 'explicit'
      } ]
    else if s.value == 'reparent'
      if post_id == window.id
        return false
      TagScript.run post_id, 'parent:' + id
    else if s.value == 'dupe'
      if post_id == window.id
        return false
      TagScript.run post_id, 'duplicate parent:' + window.id
    else if s.value == 'lock-rating'
      Post.update_batch [ {
        id: post_id
        is_rating_locked: '1'
      } ]
    else if s.value == 'lock-note'
      Post.update_batch [ {
        id: post_id
        is_note_locked: '1'
      } ]
    else if s.value == 'flag'
      Post.flag post_id
    else if s.value == 'approve'
      Post.approve post_id
    else if s.value == 'add-to-pool'
      Pool.add_post post_id, 0
    else if s.value == 'remove-from-pool'
      Pool.remove_post post_id, @pool_id
    event.stopPropagation()
    event.preventDefault()
    return

  post_add_to_hovered_list: (post_id) ->
    element = element = $$('#p' + post_id + ' > .directlink')
    if element.length > 0
      element[0].addClassName 'tag-script-applied'
      Post.applied_list.push element[0]
    if !@dragging_hash.get(post_id)
      @dragging_hash.set post_id, true
      @dragging_list.push post_id
    return
  post_mousedown: (event, post_id) ->
    if event.button != 0
      return
    if @mode == 'reparent-quick'
      @dragging_from_post = post_id
      @post_begin_drag()
    else if @mode == 'apply-tag-script'
      Post.reset_tag_script_applied()
      @dragging_from_post = post_id
      @dragging_list = new Array
      @dragging_hash = new Hash
      @post_add_to_hovered_list post_id
    else
      return

    # Prevent the mousedown from being processed; this keeps it from turning into
    # a real drag action, which will suppress our mouseover/mouseout messages.  We
    # only do this when the tag script is enabled, so we don't mess with regular
    # clicks.
    event.preventDefault()
    event.stopPropagation()
    return
  post_begin_drag: (type) ->
    document.body.addClassName 'dragging-to-post'
    return
  post_end_drag: ->
    document.body.removeClassName 'dragging-to-post'
    @dragging_from_post = null
    return
  post_mouseup: (event, post_id) ->
    if event.button != 0
      return
    if !@dragging_from_post
      return
    if @mode == 'reparent-quick'
      if post_id
        notice 'Updating post'
        Post.update_batch [ {
          id: @dragging_from_post
          parent_id: post_id
        } ]
      @post_end_drag()
      return
    else if @mode == 'apply-tag-script'
      if post_id
        return

      # We clicked or dragged some posts to apply a tag script; process it.
      tag_script = TagScript.TagEditArea.value
      TagScript.run @dragging_list, tag_script
      @dragging_from_post = null
      @dragging_active = false
      @dragging_list = null
      @dragging_hash = null
    return
  post_mouseover: (event, post_id) ->
    post = $('p' + post_id)
    style = get_style_for_mode(@mode)
    post.down('span').setStyle style
    if @mode != 'apply-tag-script'
      return
    if !@dragging_from_post
      return
    if post_id != @dragging_from_post
      @dragging_active = true
    @post_add_to_hovered_list post_id
    return
  post_mouseout: (event, post_id) ->
    post = $('p' + post_id)
    post.down('span').setStyle background: ''
    return
  apply_tag_script_to_all_posts: ->
    tag_script = TagScript.TagEditArea.value
    post_ids = Post.posts.inject([], (list, pair) ->
      list.push pair[0]
      list
    )
    TagScript.run post_ids, tag_script
    return
