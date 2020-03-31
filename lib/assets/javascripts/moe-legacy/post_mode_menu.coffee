window.PostModeMenu =
  mode: 'view'
  init: (pool_id) ->
    try

      ### This part doesn't work on IE7; for now, let's allow execution to continue so at least some initialization is run ###

      ### If pool_id isn't null, it's the pool that we're currently searching for. ###

      @pool_id = pool_id
      color_element = $('mode-box')
      @original_style = border: color_element.getStyle('border')
      if Cookie.get('mode') == ''
        Cookie.put 'mode', 'view'
        $('mode').value = 'view'
      else
        $('mode').value = Cookie.get('mode')
    catch e
    @vote_score = Cookie.get('vote')
    if @vote_score == ''
      @vote_score = 1
      Cookie.put 'vote', @vote_score
    else
      @vote_score = +@vote_score
    Post.posts.each (p) ->
      post_id = p[0]
      post = p[1]
      span = $('p' + post.id)
      if span == null or span == undefined
        return

      ### Use post_id here, not post, since the post object can be replaced later after updates. ###

      span.down('A').observe 'click', (e) ->
        PostModeMenu.click e, post_id
        return
      span.down('A').observe 'mousedown', (e) ->
        PostModeMenu.post_mousedown e, post_id
        return
      span.down('A').observe 'mouseover', (e) ->
        PostModeMenu.post_mouseover e, post_id
        return
      span.down('A').observe 'mouseout', (e) ->
        PostModeMenu.post_mouseout e, post_id
        return
      span.down('A').observe 'mouseup', (e) ->
        PostModeMenu.post_mouseup e, post_id
        return
      return
    document.observe 'mouseup', (e) ->
      PostModeMenu.post_mouseup e, null
      return
    Event.observe window, 'pagehide', (e) ->
      PostModeMenu.post_end_drag()
      return
    @change()
    return
  set_vote: (score) ->
    @vote_score = score
    Cookie.put 'vote', @vote_score
    Post.update_vote_widget 'vote-menu', @vote_score
    return
  get_style_for_mode: (s) ->
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
  change: ->
    if !$('mode')
      return
    s = $F('mode')
    Cookie.put 'mode', s, 7
    PostModeMenu.mode = s
    if s.value != 'edit'
      $('quick-edit').hide()
    if s.value != 'apply-tag-script'
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
      Pool.remove_post post_id, PostModeMenu.pool_id
    event.stopPropagation()
    event.preventDefault()
    return
  dragging_from_post: null
  dragging_active: false
  dragging_list: null
  dragging_hash: null
  post_add_to_hovered_list: (post_id) ->
    element = element = $$('#p' + post_id + ' > .directlink')
    if element.length > 0
      element[0].addClassName 'tag-script-applied'
      Post.applied_list.push element[0]
    if !PostModeMenu.dragging_hash.get(post_id)
      PostModeMenu.dragging_hash.set post_id, true
      PostModeMenu.dragging_list.push post_id
    return
  post_mousedown: (event, post_id) ->
    if event.button != 0
      return
    if PostModeMenu.mode == 'reparent-quick'
      PostModeMenu.dragging_from_post = post_id
      PostModeMenu.post_begin_drag()
    else if PostModeMenu.mode == 'apply-tag-script'
      Post.reset_tag_script_applied()
      PostModeMenu.dragging_from_post = post_id
      PostModeMenu.dragging_list = new Array
      PostModeMenu.dragging_hash = new Hash
      PostModeMenu.post_add_to_hovered_list post_id
    else
      return

    ### Prevent the mousedown from being processed; this keeps it from turning into
    # a real drag action, which will suppress our mouseover/mouseout messages.  We
    # only do this when the tag script is enabled, so we don't mess with regular
    # clicks. 
    ###

    event.preventDefault()
    event.stopPropagation()
    return
  post_begin_drag: (type) ->
    document.body.addClassName 'dragging-to-post'
    return
  post_end_drag: ->
    document.body.removeClassName 'dragging-to-post'
    PostModeMenu.dragging_from_post = null
    return
  post_mouseup: (event, post_id) ->
    if event.button != 0
      return
    if !PostModeMenu.dragging_from_post
      return
    if PostModeMenu.mode == 'reparent-quick'
      if post_id
        notice 'Updating post'
        Post.update_batch [ {
          id: PostModeMenu.dragging_from_post
          parent_id: post_id
        } ]
      PostModeMenu.post_end_drag()
      return
    else if PostModeMenu.mode == 'apply-tag-script'
      if post_id
        return

      ### We clicked or dragged some posts to apply a tag script; process it. ###

      tag_script = TagScript.TagEditArea.value
      TagScript.run PostModeMenu.dragging_list, tag_script
      PostModeMenu.dragging_from_post = null
      PostModeMenu.dragging_active = false
      PostModeMenu.dragging_list = null
      PostModeMenu.dragging_hash = null
    return
  post_mouseover: (event, post_id) ->
    post = $('p' + post_id)
    style = PostModeMenu.get_style_for_mode(PostModeMenu.mode)
    post.down('span').setStyle style
    if PostModeMenu.mode != 'apply-tag-script'
      return
    if !PostModeMenu.dragging_from_post
      return
    if post_id != PostModeMenu.dragging_from_post
      PostModeMenu.dragging_active = true
    PostModeMenu.post_add_to_hovered_list post_id
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
window.TagScript =
  TagEditArea: null
  load: ->
    @TagEditArea.value = Cookie.get('tag-script')
    return
  save: ->
    Cookie.put 'tag-script', @TagEditArea.value
    return
  init: (element, x) ->
    @TagEditArea = element
    TagScript.load()
    @TagEditArea.observe 'change', (e) ->
      TagScript.save()
      return
    @TagEditArea.observe 'focus', (e) ->
      Post.reset_tag_script_applied()
      return

    ### This mostly keeps the tag script field in sync between windows, but it
    # doesn't work in Opera, which sends focus events before blur events. 
    ###

    Event.on window, 'unload', ->
      TagScript.save()
      return
    document.observe 'focus', (e) ->
      TagScript.load()
      return
    return
  parse: (script) ->
    script.match /\[.+?\]|\S+/g
  test: (tags, predicate) ->
    split_pred = predicate.match(/\S+/g)
    is_true = true
    split_pred.each (x) ->
      if x[0] == '-'
        if tags.include(x.substr(1, 100))
          is_true = false
          throw $break
      else
        if !tags.include(x)
          is_true = false
          throw $break
      return
    is_true
  process: (tags, command) ->
    if command.match(/^\[if/)
      match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/)
      if TagScript.test(tags, match[1])
        TagScript.process tags, match[2]
      else
        tags
    else if command == '[reset]'
      []
    else if command[0] == '-' and command.indexOf('-pool:') != 0
      tags.reject (x) ->
        x == command.substr(1, 100)
    else
      tags.push command
      tags
  run: (post_ids, tag_script, finished) ->
    if !Object.isArray(post_ids)
      post_ids = $A([ post_ids ])
    commands = TagScript.parse(tag_script) or []
    posts = new Array
    post_ids.each (post_id) ->
      post = Post.posts.get(post_id)
      old_tags = post.tags.join(' ')
      commands.each (x) ->
        post.tags = TagScript.process(post.tags, x)
        return
      posts.push
        id: post_id
        old_tags: old_tags
        tags: post.tags.join(' ')
      return
    notice 'Updating ' + posts.length + (if post_ids.length == 1 then ' post' else ' posts')
    Post.update_batch posts, finished
    return

window.PostQuickEdit = (container) ->
  @container = container
  @submit_event = @submit_event.bindAsEventListener(this)
  @container.down('form').observe 'submit', @submit_event
  @container.down('.cancel').observe 'click', ((e) ->
    e.preventDefault()
    @hide()
    return
  ).bindAsEventListener(this)
  @container.down('#post_tags').observe 'keydown', ((e) ->
    if e.keyCode == Event.KEY_ESC
      e.stop()
      @hide()
      return
    if e.keyCode != Event.KEY_RETURN
      return
    @submit_event e
    return
  ).bindAsEventListener(this)
  return

PostQuickEdit::show = (post_id) ->
  Post.hover_info_pin post_id
  post = Post.posts.get(post_id)
  @post_id = post_id
  @old_tags = post.tags.join(' ')
  @container.down('#post_tags').value = post.tags.join(' ') + ' rating:' + post.rating.substr(0, 1) + ' '
  @container.show()
  @container.down('#post_tags').focus()
  return

PostQuickEdit::hide = ->
  @container.hide()
  Post.hover_info_pin null
  return

PostQuickEdit::submit_event = (e) ->
  e.stop()
  @hide()
  Post.update_batch [ {
    id: @post_id
    tags: @container.down('#post_tags').value
    old_tags: @old_tags
  } ], (->
    notice 'Post updated'
    @hide()
    return
  ).bind(this)
  return
