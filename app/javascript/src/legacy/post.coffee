window.Post =
  posts: new Hash
  tag_types: new Hash
  votes: new Hash
  tag_type_names: [
    'general'
    'artist'
    ''
    'copyright'
    'character'
    'circle'
    'faults'
  ]
  find_similar: ->
    old_source_name = $('post_source').name
    old_file_name = $('post_file').name
    old_target = $('edit-form').target
    old_action = $('edit-form').action
    $('post_source').name = 'url'
    $('post_file').name = 'file'
    $('edit-form').target = '_blank'
    $('edit-form').action = 'http://danbooru.iqdb.hanyuu.net/'
    $('edit-form').submit()
    $('post_source').name = old_source_name
    $('post_file').name = old_file_name
    $('edit-form').target = old_target
    $('edit-form').action = old_action
    return
  make_request: (path, params, finished) ->
    new (Ajax.Request)(path,
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters: params
      onFailure: (req) ->
        resp = req.responseJSON
        notice 'Error: ' + resp.reason
        return
      onSuccess: (resp) ->
        resp = resp.responseJSON
        Post.register_resp resp

        ### Fire posts:update, to allow observers to update their display on change. ###

        post_ids = new Hash
        i = 0
        while i < resp.posts.length
          post_ids.set resp.posts[i].id, true
          ++i
        document.fire 'posts:update',
          resp: resp
          post_ids: post_ids
        if finished
          finished resp
        return
)
  approve: (post_id, delete_reason, finished) ->
    notice 'Approving post #' + post_id
    params = {}
    params['ids[' + post_id + ']'] = '1'
    params['commit'] = if delete_reason then 'Delete' else 'Approve'
    if delete_reason
      params['reason'] = delete_reason

    completion = ->
      notice if delete_reason then 'Post deleted' else 'Post approved'
      if finished
        finished post_id
      else
        if $('p' + post_id)
          $('p' + post_id).removeClassName 'pending'
        if $('pending-notice')
          $('pending-notice').hide()
      return

    Post.make_request '/post/moderate.json', params, completion
  undelete: (post_id, finished) ->
    Post.make_request '/post/undelete.json', { id: post_id }, finished
  applied_list: []
  reset_tag_script_applied: ->
    i = 0
    while i < Post.applied_list.length
      Post.applied_list[i].removeClassName 'tag-script-applied'
      ++i
    Post.applied_list = []
    return
  update_batch: (posts, finished) ->
    original_count = posts.length
    if TagCompletion

      ### Tell TagCompletion about recently used tags. ###

      posts.each (post) ->
        if post.tags == null or post.tags == undefined
          return
        TagCompletion.add_recent_tags_from_update post.tags, post.old_tags
        return

    ### posts is a hash of id: { post }.  Convert this to a Rails-format object array. ###

    params_array = []
    posts.each (post) ->
      $H(post).each (pair2) ->
        s = 'post[][' + pair2.key + ']=' + window.encodeURIComponent(pair2.value)
        params_array.push s
        return
      return

    complete = (resp) ->
      resp.posts.each (post) ->
        Post.update_styles post
        element = $$('#p' + post.id + ' > .directlink')
        if element.length > 0
          element[0].addClassName 'tag-script-applied'
          Post.applied_list.push element[0]
        return
      notice (if original_count == 1 then 'Post' else 'Posts') + ' updated'
      if finished
        finished resp.posts
      return

    params = params_array.join('&')
    Post.make_request '/post/update_batch.json', params, complete
    return
  update_styles: (post) ->
    e = $('p' + post.id)
    if !e
      return
    if post['has_children']
      e.addClassName 'has-children'
    else
      e.removeClassName 'has-children'
    if post['parent_id']
      e.addClassName 'has-parent'
    else
      e.removeClassName 'has-parent'
    return
  update: (post_id, params, finished) ->
    notice 'Updating post #' + post_id
    params['id'] = post_id
    new (Ajax.Request)('/post/update.json',
      parameters: params
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          notice 'Post updated'
          # Update the stored post.
          Post.register resp.post
          Post.register_tags resp.tags
          Post.update_styles resp.post
          element = element = $$('#p' + post_id + ' > .directlink')
          if element.length > 0
            element[0].addClassName 'tag-script-applied'
            Post.applied_list.push element[0]
          if finished
            finished resp.post
        else
          notice 'Error: ' + resp.reason
        return
)
    return
  activate_posts: (post_ids, finished) ->
    notice 'Activating ' + post_ids.length + (if post_ids.length == 1 then ' post' else ' posts')
    params = {}
    params['post_ids[]'] = post_ids
    new (Ajax.Request)('/post/activate.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters: params
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          if finished
            finished resp
        else
          notice 'Error: ' + resp.reason
        return
)
    return
  activate_all_posts: ->
    post_ids = []
    Post.posts.each (pair) ->

      ### Only activate posts that are actually displayed; we may have others registered. ###

      if $('p' + pair.key)
        post_ids.push pair.key
      return
    Post.activate_posts post_ids, (resp) ->
      if resp.count == 0
        notice 'No posts were activated.'
      else
        notice resp.count + (if resp.count == 1 then ' post' else ' posts') + ' activated'
      return
    return
  activate_post: (post_id) ->
    Post.update_batch [ {
      id: post_id
      is_held: false
    } ], ->
      post = Post.posts.get(post_id)
      if post.is_held
        notice 'Couldn\'t activate post'
      else
        $('held-notice').remove()
      return
    return
  init_add_to_favs: (post_id, add_to_favs, remove_from_favs) ->

    update_add_to_favs = (e) ->
      if e != null and e != undefined and (e.memo.post_ids.get(post_id) == null or e.memo.post_ids.get(post_id) == undefined)
        return
      vote = Post.votes.get(post_id) or 0
      add_to_favs.show vote < 3
      remove_from_favs.show vote >= 3
      return

    update_add_to_favs()
    document.on 'posts:update', update_add_to_favs
    return
  vote: (post_id, score) ->
    if score > 3
      return
    notice 'Voting...'
    Post.make_request '/post/vote.json', {
      id: post_id
      score: score
    }, (resp) ->
      notice 'Vote saved'
      return
    return
  flag: (id, finished) ->
    reason = prompt('Why should this post be flagged for deletion?', '')
    if !reason
      return false

    complete = ->
      notice 'Post was flagged for deletion'
      if finished
        finished id
      else
        e = $('p' + id)
        if e
          e.addClassName 'flagged'
      return

    Post.make_request '/post/flag.json', {
      'id': id
      'reason': reason
    }, complete
  unflag: (id, finished) ->

    complete = ->
      notice 'Post was approved'
      if finished
        finished id
      else
        e = $('p' + id)
        if e
          e.removeClassName 'flagged'
      return

    Post.make_request '/post/flag.json', {
      id: id
      unflag: 1
    }, complete
  observe_text_area: (field_id) ->
    $(field_id).observe 'keydown', (e) ->
      if e.keyCode == Event.KEY_RETURN
        e.stop()
        @up('form').simulate_submit()
      return
    return
  get_post_tags_by_type: (post) ->
    results = new Hash
    post.tags.each (tag) ->
      tag_type = Post.tag_types.get(tag)

      ### We can end up not knowing a tag's type due to tag script editing giving us
      # tags we weren't told the type of. 
      ###

      if !tag_type
        tag_type = 'general'
      list = results.get(tag_type)
      if !list
        list = []
        results.set tag_type, list
      list.push tag
      return
    results
  get_post_tags_with_type: (post) ->
    tag_types = Post.get_post_tags_by_type(post)
    types = tag_types.keys()
    type_order = [
      'artist'
      'circle'
      'copyright'
      'character'
      'faults'
      'general'
    ]
    types = types.sort((a, b) ->
      a_idx = type_order.indexOf(a)
      if a_idx == -1
        a_idx = 999
      b_idx = type_order.indexOf(b)
      if b_idx == -1
        b_idx = 999
      a_idx - b_idx
    )
    results = new Array
    types.each (type) ->
      tags = tag_types.get(type)
      tags.each (tag) ->
        results.push [
          tag
          type
        ]
        return
      return
    results
  register_resp: (resp) ->
    if resp.posts
      Post.register_posts resp.posts
    if resp.tags
      Post.register_tags resp.tags
    if resp.votes
      Post.register_votes resp.votes
    if resp.pools
      Pool.register_pools resp.pools
    if resp.pool_posts
      Pool.register_pool_posts resp.pool_posts, resp.posts
    return
  register: (post) ->
    post.tags = post.tags.match(/\S+/g) or []
    post.match_tags = post.tags.clone()
    post.match_tags.push 'rating:' + post.rating.charAt(0)
    post.match_tags.push 'status:' + post.status
    @posts.set post.id, post
    return
  register_posts: (posts) ->
    posts.each (post) ->
      Post.register post
      return
    return
  unregister_all: ->
    @posts = new Hash
    return
  register_tags: (tags, no_send_to_completion) ->
    @tag_types.update tags

    ### If no_send_to_completion is true, this data is coming from completion, so there's
    # no need to send it back. 
    ###

    if TagCompletion and !no_send_to_completion
      TagCompletion.update_tag_types()
    return
  register_votes: (votes) ->
    @votes.update votes
    return
  blacklists: []
  is_blacklisted: (post_id) ->
    post = Post.posts.get(post_id)

    has_tag = (tag) ->
      post.match_tags.indexOf(tag) != -1

    ### This is done manually, since this needs to be fast and Prototype's functions are
    # too slow. 
    ###

    blacklist_applies = (b) ->
      require = b.require
      require_len = require.length
      j = undefined
      j = 0
      while j < require_len
        if !has_tag(require[j])
          return false
        ++j
      exclude = b.exclude
      exclude_len = exclude.length
      j = 0
      while j < exclude_len
        if has_tag(exclude[j])
          return false
        ++j
      true

    blacklists = Post.blacklists
    len = blacklists.length
    i = 0
    while i < len
      b = blacklists[i]
      if blacklist_applies(b)
        return true
      ++i
    false
  apply_blacklists: ->
    Post.blacklists.each (b) ->
      b.hits = 0
      return
    count = 0
    Post.posts.each (pair) ->
      thumb = $('p' + pair.key)
      if !thumb
        return
      post = pair.value
      has_tag = post.match_tags.member.bind(post.match_tags)
      post.blacklisted = []
      if post.id != Post.blacklist_options.exclude
        Post.blacklists.each (b) ->
          if b.require.all(has_tag) and !b.exclude.any(has_tag)
            b.hits++
            if !Post.disabled_blacklists[b.tags]
              post.blacklisted.push b
          return
      bld = post.blacklisted.length > 0

      ### The class .javascript-hide hides elements only if JavaScript is enabled, and is
      # applied to all posts by default; we remove the class to show posts.  This prevents
      # posts from being shown briefly during page load before this script is executed,
      # but also doesn't break the page if JavaScript is disabled. 
      ###

      count += bld
      if Post.blacklist_options.replace
        if bld
          thumb.src = Moebooru.urls.images.blank

          ### Trying to work around Firefox displaying the old thumb.src briefly before loading
          # the blacklisted thumbnail, even though they're applied at the same time: 
          ###

          f = (event) ->
            img = event.target
            img.stopObserving 'load'
            img.stopObserving 'error'
            img.src = '/blacklisted-preview.png'
            img.removeClassName 'javascript-hide'
            return

          thumb.observe 'load', f
          thumb.observe 'error', f
        else
          thumb.src = post.preview_url
          thumb.removeClassName 'javascript-hide'
      else
        if bld
          thumb.addClassName 'javascript-hide'
        else
          thumb.removeClassName 'javascript-hide'
      return
    if Post.countText
      Post.countText.update count
    notice = $('blacklisted-notice')
    if notice
      notice.show count > 0
    count
  current_blacklists: null
  hide_inactive_blacklists: true
  disabled_blacklists: {}
  blacklists_update_disabled: ->
    Post.blacklists.each (b) ->
      if !b.a
        return
      if Post.disabled_blacklists[b.tags] or b.hits == 0
        b.a.addClassName 'blacklisted-tags-disabled'
      else
        b.a.removeClassName 'blacklisted-tags-disabled'
      return
    return
  init_blacklisted: (options) ->
    Post.blacklist_options = Object.extend({
      replace: false
      exclude: null
    }, options)
    bl_entries = undefined
    if Post.current_blacklists
      bl_entries = Post.current_blacklists
    else
      bl_entries = JSON.parse(jQuery('#user-blacklisted-tags').text())
    Post.blacklists = []
    bl_entries.each (val) ->
      s = val.replace(/(rating:[qes])\w+/, '$1')
      tags = s.match(/\S+/g)
      if !tags
        return
      b = 
        tags: tags
        original_tag_string: val
        require: []
        exclude: []
        hits: 0
      tags.each (tag) ->
        if tag.charAt(0) == '-'
          b.exclude.push tag.slice(1)
        else
          b.require.push tag
        return
      Post.blacklists.push b
      return
    Post.countText = $('blacklist-count')
    if Post.countText
      Post.countText.update ''
    Post.apply_blacklists()
    sidebar = $('blacklisted-sidebar')
    if sidebar
      sidebar.show()
    list = $('blacklisted-list')
    if list
      while list.firstChild
        list.removeChild list.firstChild
      Post.blacklists.sort (a, b) ->
        if a.hits == 0 and b.hits > 0
          return 1
        if a.hits > 0 and b.hits == 0
          return -1
        a.tags.join(' ').localeCompare b.tags.join(' ')
      inactive_blacklists_hidden = 0
      Post.blacklists.each (b) ->
        if Post.hide_inactive_blacklists and !b.hits
          ++inactive_blacklists_hidden
          return
        li = list.appendChild(document.createElement('li'))
        li.className = 'blacklisted-tags'
        li.style.position = 'relative'
        del = li.appendChild($(document.createElement('a')))
        del.style.position = 'absolute'
        del.style.left = '-0.75em'
        del.href = '#'
        del.update '⊘'
        del.observe 'click', (event) ->

          ### We need to call run_login_onclick ourself, since this form isn't created with the form helpers. ###

          if !User.run_login_onclick(event)
            return false
          event.stop()
          tag = b.original_tag_string
          User.modify_blacklist [], [ tag ], (resp) ->
            notice 'Unblacklisted "' + tag + '"'
            Post.current_blacklists = resp.result
            Post.init_blacklisted()
            return
          return
        li.appendChild document.createTextNode('» ')
        a = li.appendChild(document.createElement('a'))
        b.a = a
        a.href = '#'
        a.className = 'no-focus-outline'
        if !b.hits
          a.addClassName 'blacklisted-tags-disabled'
        else
          $(a).observe 'click', (event) ->
            Post.disabled_blacklists[b.tags] = !Post.disabled_blacklists[b.tags]
            Post.apply_blacklists()
            Post.blacklists_update_disabled()
            event.stop()
            return
        tags = a.appendChild(document.createTextNode(b.tags.join(' ')))
        li.appendChild document.createTextNode(' ')
        span = li.appendChild(document.createElement('span'))
        span.className = 'post-count'
        if b.hits > 0
          span.appendChild document.createTextNode('(' + b.hits + ')')
        return

      ### Add the "Show all blacklists" button.  If Post.hide_inactive_blacklists is false, then
      # we've already clicked it and hidden it, so don't recreate it. 
      ###

      if Post.hide_inactive_blacklists and inactive_blacklists_hidden > 0
        li = list.appendChild(document.createElement('li'))
        li.className = 'no-focus-outline'
        li.id = 'blacklisted-tag-show-all'
        a = li.appendChild(document.createElement('a'))
        a.href = '#'
        a.className = 'no-focus-outline'
        $(a).observe 'click', (event) ->
          event.stop()
          $('blacklisted-tag-show-all').hide()
          Post.hide_inactive_blacklists = false
          Post.init_blacklisted()
          return
        tags = a.appendChild(document.createTextNode('» Show all blacklists'))
        li.appendChild document.createTextNode(' ')
    Post.blacklists_update_disabled()
    return
  blacklist_add_commit: ->
    tag = $('add-blacklist').value
    if tag == ''
      return
    $('add-blacklist').value = ''
    User.modify_blacklist tag, [], (resp) ->
      notice 'Blacklisted "' + tag + '"'
      Post.current_blacklists = resp.result
      Post.init_blacklisted()
      return
    return
  last_click_id: null
  check_avatar_blacklist: (post_id, id) ->
    if id and id == @last_click_id
      return true
    @last_click_id = id
    if !Post.is_blacklisted(post_id)
      return true
    notice 'This post matches one of your blacklists.  Click again to open.'
    false
  resize_image: ->
    img = $('image')
    if img.original_width == null or img.original_width == undefined
      img.original_width = img.width
      img.original_height = img.height
    ratio = 1
    if img.scale_factor == 1 or img.scale_factor == null or img.scale_factor == undefined

      ### Use clientWidth for sizing the width, and the window height for the height.
      # This prevents needing to scroll horizontally to center the image. 
      ###

      client_width = $('right-col').clientWidth - 15
      client_height = window.innerHeight - 15
      ratio = Math.min(ratio, client_width / img.original_width)
      ratio = Math.min(ratio, client_height / img.original_height)
    img.width = img.original_width * ratio
    img.height = img.original_height * ratio
    img.scale_factor = ratio
    if window.Note
      i = 0
      while i < window.Note.all.length
        window.Note.all[i].adjustScale()
        ++i
    return
  get_scroll_offset_to_center: (element) ->
    window_size = document.viewport.getDimensions()
    offset = element.cumulativeOffset()
    left_spacing = (window_size.width - (element.offsetWidth)) / 2
    top_spacing = (window_size.height - (element.offsetHeight)) / 2
    scroll_x = offset.left - left_spacing
    scroll_y = offset.top - top_spacing
    [
      scroll_x
      scroll_y
    ]
  center_image: (img) ->

    ### Make sure we have enough space to scroll far enough to center the image.  Set a
    # minimum size on the body to give us more space on the right and bottom, and add
    # a padding to the image to give more space on the top and left. 
    ###

    if !img
      img = $('image')
    if !img
      return

    ### Any existing padding (possibly from a previous call to this function) will be
    # included in cumulativeOffset and throw things off, so clear it. 
    ###

    img.setStyle
      paddingLeft: 0
      paddingTop: 0
    target_offset = Post.get_scroll_offset_to_center(img)
    padding_left = -target_offset[0]
    if padding_left < 0
      padding_left = 0
    img.setStyle paddingLeft: padding_left + 'px'
    padding_top = -target_offset[1]
    if padding_top < 0
      padding_top = 0
    img.setStyle paddingTop: padding_top + 'px'
    window_size = document.viewport.getDimensions()
    required_width = target_offset[0] + window_size.width
    required_height = target_offset[1] + window_size.height
    $(document.body).setStyle
      minWidth: required_width + 'px'
      minHeight: required_height + 'px'

    ### Resizing the body may shift the image to the right, since it's centered in the content.
    # Recalculate offsets with the new cumulativeOffset. 
    ###

    target_offset = Post.get_scroll_offset_to_center(img)
    window.scroll target_offset[0], target_offset[1]
    return
  scale_and_fit_image: (img) ->
    if !img
      img = $('image')
    if !img
      return
    if img.original_width == null or img.original_width == undefined
      img.original_width = img.width
      img.original_height = img.height
    window_size = document.viewport.getDimensions()
    client_width = window_size.width
    client_height = window_size.height

    ### Zoom the image to fit the viewport. ###

    ratio = client_width / img.original_width
    if img.original_height * ratio > client_height
      ratio = client_height / img.original_height
    if ratio < 1
      img.width = img.original_width * ratio
      img.height = img.original_height * ratio
    @center_image img
    Post.adjust_notes()
    return
  adjust_notes: ->
    if !window.Note
      return
    i = 0
    while i < window.Note.all.length
      window.Note.all[i].adjustScale()
      ++i
    return
  highres: ->
    img = $('image')
    if img.already_resized
      return
    img.already_resized = true
    # un-resize
    if img.scale_factor != null and img.scale_factor != undefined and img.scale_factor != 1
      Post.resize_image()

    f = ->
      img.original_height = null
      img.original_width = null
      highres = $('highres-show')
      img.height = highres.getAttribute('link_height')
      img.width = highres.getAttribute('link_width')
      $('note-container').insert after: img
      img.src = highres.href
      if window.Note
        window.Note.all.invoke 'adjustScale'
      return

    # Clear the image before loading the new one, so it doesn't show the old image
    # at the new resolution while the new one loads.  Hide it, so we don't flicker
    # a placeholder frame.
    if $('resized_notice')
      $('resized_notice').hide()
    img.height = img.width = 0
    img.src = ''
    img.remove()
    f img
    return
  set_same_user: (creator_id) ->
    old = $('creator-id-css')
    if old
      old.parentNode.removeChild old
    css = '.creator-id-' + creator_id + ' .directlink { background-color: #300 !important; }'
    style = document.createElement('style')
    style.id = 'creator-id-css'
    style.type = 'text/css'
    if style.styleSheet
      style.styleSheet.cssText = css
    else
      style.appendChild document.createTextNode(css)
    document.getElementsByTagName('head')[0].appendChild style
    return
  init_post_list: ->
    Post.posts.each (p) ->
      post_id = p[0]
      post = p[1]
      directlink = $('p' + post_id)
      if !directlink
        return
      directlink = directlink.down('.directlink')
      if !directlink
        return
      directlink.observe 'mouseover', ((event) ->
        Post.set_same_user post.creator_id
        false
      ), true
      directlink.observe 'mouseout', ((event) ->
        Post.set_same_user null
        false
      ), true
      return
    return
  init_hover_thumb: (hover, post_id, thumb, container) ->

    ### Hover thumbs trigger rendering bugs in IE7. ###

    if Prototype.Browser.IE
      return
    hover.observe 'mouseover', (e) ->
      Post.hover_thumb_mouse_over post_id, hover, thumb, container
      return
    hover.observe 'mouseout', (e) ->
      if e.relatedTarget == thumb
        return
      Post.hover_thumb_mouse_out thumb
      return
    if !thumb.hover_init
      thumb.hover_init = true
      thumb.observe 'mouseout', (e) ->
        Post.hover_thumb_mouse_out thumb
        return
    return
  hover_thumb_mouse_over: (post_id, AlignItem, image, container) ->
    post = Post.posts.get(post_id)
    image.hide()
    offset = AlignItem.cumulativeOffset()
    image.style.width = 'auto'
    image.style.height = 'auto'
    if Post.is_blacklisted(post_id)
      image.src = Moebooru.urls.images.blacklistedPreview
    else
      image.src = post.preview_url
      if post.status != 'deleted'
        image.style.width = post.actual_preview_width + 'px'
        image.style.height = post.actual_preview_height + 'px'
    container_top = container.cumulativeOffset().top
    container_bottom = container_top + container.getHeight() - 1

    ### Normally, align to the item we're hovering over.  If the image overflows over
    # the bottom edge of the container, shift it upwards to stay in the container,
    # unless the container's too small and that would put it over the top. 
    ###

    y = offset.top - 2

    ### -2 for top 2px border ###

    if y + image.getHeight() > container_bottom
      bottom_aligned_y = container_bottom - image.getHeight() - 4

      ### 4 for top 2px and bottom 2px borders ###

      if bottom_aligned_y >= container_top
        y = bottom_aligned_y
    image.style.top = y + 'px'
    image.show()
    return
  hover_thumb_mouse_out: (image) ->
    image.hide()
    return
  acknowledge_new_deleted_posts: (post_id) ->
    new (Ajax.Request)('/post/acknowledge_new_deleted_posts.json', onComplete: (resp) ->
      resp = resp.responseJSON
      if resp.success
        if $('posts-deleted-notice')
          $('posts-deleted-notice').hide()
      else
        notice 'Error: ' + resp.reason
      return
)
    return
  hover_info_pin: (post_id) ->
    post = null
    if post_id != null and post_id != undefined
      post = Post.posts.get(post_id)
    Post.hover_info_pinned_post = post
    Post.hover_info_update()
    return
  hover_info_mouseover: (post_id) ->
    post = Post.posts.get(post_id)
    if Post.hover_info_hovered_post == post
      return
    Post.hover_info_hovered_post = post
    Post.hover_info_update()
    return
  hover_info_mouseout: ->
    if Post.hover_info_hovered_post == null or Post.hover_info_hovered_post == undefined
      return
    Post.hover_info_hovered_post = null
    Post.hover_info_update()
    return
  hover_info_hovered_post: null
  hover_info_displayed_post: null
  hover_info_shift_held: false
  hover_info_pinned_post: null
  hover_info_update: ->
    post = Post.hover_info_pinned_post
    if !post
      post = Post.hover_info_hovered_post
      if !Post.hover_info_shift_held
        post = null
    if Post.hover_info_displayed_post == post
      return
    Post.hover_info_displayed_post = post
    hover = $('index-hover-info')
    overlay = $('index-hover-overlay')
    if !post
      hover.hide()
      overlay.hide()
      overlay.down('IMG').src = Moebooru.urls.images.blank
      return
    hover.down('#hover-dimensions').innerHTML = post.width + 'x' + post.height
    hover.select('#hover-tags SPAN A').each (elem) ->
      elem.innerHTML = ''
      return
    tags_by_type = Post.get_post_tags_by_type(post)
    tags_by_type.each (key) ->
      elem = $('hover-tag-' + key[0])
      list = []
      key[1].each (tag) ->
        list.push tag
        return
      elem.innerHTML = list.join(' ')
      return
    if post.rating == 's'
      hover.down('#hover-rating').innerHTML = 's'
    else if post.rating == 'q'
      hover.down('#hover-rating').innerHTML = 'q'
    else if post.rating == 'e'
      hover.down('#hover-rating').innerHTML = 'e'
    hover.down('#hover-post-id').innerHTML = post.id
    hover.down('#hover-score').innerHTML = post.score
    if post.is_shown_in_index
      hover.down('#hover-not-shown').hide()
    else
      hover.down('#hover-not-shown').show()
    hover.down('#hover-is-parent').show post.has_children
    hover.down('#hover-is-child').show post.parent_id != null and post.parent_id != undefined
    hover.down('#hover-is-pending').show post.status == 'pending'
    hover.down('#hover-is-flagged').show post.status == 'flagged'

    set_text_content = (element, text) ->
      (element.innerText or element).textContent = text
      return

    if post.status == 'flagged'
      hover.down('#hover-flagged-reason').setTextContent post.flag_detail.reason
      hover.down('#hover-flagged-by').setTextContent post.flag_detail.flagged_by
    hover.down('#hover-file-size').innerHTML = number_to_human_size(post.file_size)
    hover.down('#hover-author').innerHTML = post.author
    hover.show()

    ### Reset the box to 0x0 before polling the size, so it expands to its maximum size,
    # and read the size. 
    ###

    hover.style.left = '0px'
    hover.style.top = '0px'
    hover_width = hover.scrollWidth
    hover_height = hover.scrollHeight
    hover_thumb = $('p' + post.id).down('IMG')
    thumb_offset = hover_thumb.cumulativeOffset()
    thumb_center_x = thumb_offset[0] + hover_thumb.scrollWidth / 2
    thumb_top_y = thumb_offset[1]
    x = thumb_center_x - (hover_width / 2)
    y = thumb_top_y - hover_height

    ### Clamp the X coordinate so the box doesn't fall off the side of the screen.  Don't
    # clamp Y. 
    ###

    client_width = document.viewport.getDimensions()['width']
    if x < 0
      x = 0
    if x + hover_width > client_width
      x = client_width - hover_width
    hover.style.left = x + 'px'
    hover.style.top = y + 'px'
    overlay.down('A').href = (if User.get_use_browser() then '/post/browse#' else '/post/show/') + post.id
    overlay.down('IMG').src = post.preview_url

    ### This doesn't always align properly in Firefox if full-page zooming is being
    # used. 
    ###

    x = thumb_center_x - (post.actual_preview_width / 2)
    y = thumb_offset[1]
    overlay.style.left = x + 'px'
    overlay.style.top = y + 'px'
    overlay.show()
    return
  hover_info_shift_down: ->
    if Post.hover_info_shift_held
      return
    Post.hover_info_shift_held = true
    Post.hover_info_update()
    return
  hover_info_shift_up: ->
    if !Post.hover_info_shift_held
      return
    Post.hover_info_shift_held = false
    Post.hover_info_update()
    return
  hover_info_init: ->
    document.observe 'keydown', (e) ->
      if e.keyCode != 16
        return
      Post.hover_info_shift_down()
      return
    document.observe 'keyup', (e) ->
      if e.keyCode != 16
        return
      Post.hover_info_shift_up()
      return
    document.observe 'blur', (e) ->
      Post.hover_info_shift_up()
      return
    overlay = $('index-hover-overlay')
    Post.posts.each (p) ->
      post_id = p[0]
      post = p[1]
      span = $('p' + post.id)
      if span == null or span == undefined
        return
      span.down('A').observe 'mouseover', (e) ->
        Post.hover_info_mouseover post_id
        return
      span.down('A').observe 'mouseout', (e) ->
        if e.relatedTarget and e.relatedTarget.isParentNode(overlay)
          return
        Post.hover_info_mouseout()
        return
      return
    overlay.observe 'mouseout', (e) ->
      Post.hover_info_mouseout()
      return
    return
  highlight_posts_with_tag: (tag) ->
    Post.posts.each (p) ->
      post_id = p[0]
      post = p[1]
      thumb = $('p' + post.id)
      if !thumb
        return
      if tag and post.tags.indexOf(tag) != -1
        thumb.addClassName 'highlighted-post'
      else
        thumb.removeClassName 'highlighted-post'
      return
    return
  reparent_post: (post_id, old_parent_id, has_grandparent, finished) ->
    # If the parent has a parent, this is too complicated to handle automatically.
    if has_grandparent
      alert 'The parent post has a parent, so this post can\'t be automatically reparented.'
      return
    # Request a list of child posts.
    # The parent post itself will be returned by "parent:". This is expected;
    # it'll cause us to parent the post to itself, which unparents it
    # from the old parent.
    jQuery.ajax(
      url: '/post.json'
      data: tags: 'parent:' + old_parent_id
      dataType: 'json').done (resp) ->
      post = undefined
      i = undefined
      change_requests = []
      i = 0
      while i < resp.length
        post = resp[i]
        if post.id == old_parent_id and post.parent_id != null and post.parent_id != undefined
          alert 'The parent post has a parent, so this post can\'t be automatically reparented.'
          return
        change_requests.push
          id: resp[i].id
          tags: 'parent:' + post_id
          old_tags: ''
        ++i
      # We have the list of changes to make in change_requests.
      # Send a batch request.
      if typeof finished == 'undefined' or finished == null

        finished = ->
          document.location.reload()
          return

      Post.update_batch change_requests, finished
      return
    return
  get_url_for_post_in_pool: (post_id, pool_id) ->
    '/post/show/' + post_id + '?pool_id=' + pool_id
  jump_to_post_in_pool: (post_id, pool_id) ->
    if post_id == null or post_id == undefined
      notice 'No more posts in this pool'
      return
    window.location.href = Post.get_url_for_post_in_pool(post_id, pool_id)
    return
  InitBrowserLinks: ->
    if !User.get_use_browser()
      return

    ###
    # Break out the controller, action, ID and anchor:
    # http://url.com/post/show/123#anchor
    ###

    parse_url = (href) ->
      match = href.match(/^(https?:\/\/[^\/]+)\/([a-z]+)\/([a-z]+)\/([0-9]+)([^#]*)(#.*)?$/)
      if !match
        return null
      {
        controller: match[2]
        action: match[3]
        id: match[4]
        hash: match[6]
      }

    ###
    # Parse an index search URL and return the tags.  Only accept URLs with no other parameters;
    # this shouldn't match the paginator in post/index.
    #
    # http://url.com/post?tags=tagme
    ###

    parse_index_url = (href) ->
      match = href.match(/^(https?:\/\/[^\/]+)\/post(\/index)?\?tags=([^&]*)$/)
      if !match
        return null
      match[3]

    ### If the current page is /pool/show, make post links include both the post ID and
    # the pool ID, eg. "#12345/pool:123". 
    ###

    current = parse_url(document.location.href)
    current_pool_id = null
    if current and current.controller == 'pool' and current.action == 'show'
      current_pool_id = current.id
    $$('A').each (a) ->
      if a.hasClassName('no-browser-link') or a.up('.no-browser-link')
        return
      tags = parse_index_url(a.href)
      if tags != null and tags != undefined
        a.href = '/post/browse#/' + tags
        return
      target = parse_url(a.href)
      if !target
        return

      ### If the URL has a hash, then it's something like a post comment link, so leave it
      # alone. 
      ###

      if target.hash
        return
      if target.controller == 'post' and target.action == 'show'
        url = '/post/browse#' + target.id
        if current_pool_id != null and current_pool_id != undefined
          url += '/pool:' + current_pool_id
        a.browse_href = url
        a.orig_href = a.href
      else if target.controller == 'pool' and target.action == 'show'
        a.browse_href = '/post/browse#/pool:' + target.id
        a.orig_href = a.href
      if a.browse_href
        a.href = a.browse_href
      return
    return
  cached_sample_urls: null
  get_cached_sample_urls: ->
    if LocalStorageDisabled()
      return null

    ### If the data format is out of date, clear it. ###

    if localStorage.sample_url_format != '2'
      Post.clear_sample_url_cache()
    if Post.cached_sample_urls != null and Post.cached_sample_urls != undefined
      return Post.cached_sample_urls
    try
      sample_urls = JSON.parse(window.localStorage.sample_urls)
    catch SyntaxError
      return {}
    if sample_urls == null or sample_urls == undefined
      return {}
    Post.cached_sample_urls = sample_urls
    sample_urls
  clear_sample_url_cache: ->
    if 'sample_urls' of localStorage
      delete window.localStorage.sample_urls
    if 'sample_url_fifo' of localStorage
      delete window.localStorage.sample_url_fifo
    localStorage.sample_url_format = 2
    return
  cache_sample_urls: ->
    sample_urls = Post.get_cached_sample_urls()
    if sample_urls == null or sample_urls == undefined
      return

    ### Track post URLs in the order we see them, and push old data out. ###

    fifo = window.localStorage.sample_url_fifo or null
    fifo = if fifo then fifo.split(',') else []
    Post.posts.each (id_and_post) ->
      post = id_and_post[1]
      if post.sample_url
        sample_urls[post.id] = post.sample_url
      fifo.push post.id
      return

    ### Erase all but the most recent 1000 items. ###

    fifo = fifo.splice(-1000)

    ### Make a set of the FIFO, so we can do lookups quickly. ###

    fifo_set = {}
    fifo.each (post_id) ->
      fifo_set[post_id] = true
      return

    ### Make a list of items no longer in the FIFO to be deleted. ###

    post_ids_to_expire = []
    for post_id of sample_urls
      if !(post_id of fifo_set)
        post_ids_to_expire.push post_id

    ### Erase items no longer in the FIFO. ###

    post_ids_to_expire.each (post_id) ->
      delete sample_urls[post_id]
      return

    ### Save the cached items and FIFO back to localStorage. ###

    Post.cached_sample_urls = sample_urls
    try
      window.localStorage.sample_urls = JSON.stringify(sample_urls)
      window.localStorage.sample_url_fifo = fifo.join(',')
    catch e

      ### If this fails for some reason, clear the data. ###

      Post.clear_sample_url_cache()
      throw e
    return
  prompt_to_delete: (post_id, completed) ->
    if completed == null or completed == undefined

      completed = ->
        window.location.reload()
        return

    flag_detail = Post.posts.get(post_id).flag_detail
    default_reason = if flag_detail then flag_detail.reason else ''
    reason = prompt('Reason:', default_reason)
    if !reason
      return false
    Post.approve post_id, reason, completed
    true
