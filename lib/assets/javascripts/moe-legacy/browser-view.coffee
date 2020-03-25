###
# We have a few competing goals:
#
# First, be as responsive as possible.  Preload nearby post HTML and their images.
#
# If data in a post page changes, eg. if the user votes, then coming back to the page
# later should retain the changes.  This means either requesting the page again, or
# retaining the document node and reusing it, so we preserve the changes that were
# made in-place.
#
# Don't use too much memory.  If we keep every document node in memory as we use it,
# the images will probably be kept around too.  Release older nodes, so the browser
# is more likely to release images that havn't been used in a while.
#
# We do the following:
# - When we load a new post, it's formatted and its scripts are evaluated normally.
# - When we're replacing the displayed post, its node is stashed away in a node cache.
# - If we come back to the post while it's in the node cache, we'll use the node directly.
# - HTML and images for posts are preloaded.  We don't use a simple mechanism like
#   Preload.preload_raw, because Opera's caching is broken for XHR and it'll always
#   do a slow revalidation.
# - We don't depend on browser caching for HTML.  That would require us to expire a
#   page when we switch away from it if we've made any changes (eg. voting), so we
#   don't pull an out-of-date page next time.  This is slower, and would require us
#   to be careful about expiring the cache.
###
class window.BrowserView
  constructor: (@container) ->
    # The post that we currently want to display.  This will be either one of the
    # current html_preloads, or be the displayed_post_id.
    @wanted_post_id = null
    @wanted_post_frame = null

    # The post that's currently actually being displayed.
    @displayed_post_id = null
    @displayed_post_frame = null
    @current_ajax_request = null
    @last_preload_request = []
    @last_preload_request_active = false
    @image_pool = new ImgPoolHandler
    @img_box = @container.down('.image-box')

    # In Opera 10.63, the img.complete property is not reset to false after changing the
    # src property.  Blits from images to the canvas silently fail, with nothing being
    # blitted and no exception raised.  This causes blank canvases to be displayed, because
    # we have no way of telling whether the image is blittable or if the blit succeeded.
    if !Prototype.Browser.Opera
      @canvas = create_canvas_2d()
    if @canvas
      @canvas.hide()
      @img_box.appendChild @canvas
    @zoom_level = 0

    # True if the post UI is visible.
    @post_ui_visible = true
    Event.on window, 'resize', @window_resize_event
    document.on 'viewer:vote', (event) => @vote_widget.set event.memo.score if @vote_widget

    TagCompletion.init() if TagCompletion

    # Double-clicking the main image, or on nothing, toggles the thumb bar.
    @container.down('.image-container').on 'dblclick', '.image-container', (event) =>
      # Watch out: Firefox fires dblclick events for all buttons, with the standard
      # button maps, but IE only fires it for left click and doesn't set button at
      # all, so event.isLeftClick won't work.
      return if event.button
      event.stop()
      document.fire 'viewer:set-thumb-bar', toggle: true

    # Image controls:
    document.on 'viewer:view-large-toggle', (e) => @toggle_view_large_image()
    @container.down('.post-info').on 'click', '.toggle-zoom', (e) =>
      e.stop()
      @toggle_view_large_image()

    @container.down('.parent-post').down('A').on 'click', @parent_post_click_event
    @container.down('.child-posts').down('A').on 'click', @child_posts_click_event
    @container.down('.post-frames').on 'click', '.post-frame-link', (e, item) =>
      e.stop()

      # Change the displayed post frame to the one that was clicked.  Since all post frames
      # are usually displayed in the thumbnail view, set center_thumbs to true to recenter
      # on the thumb that was clicked, so it's clearer what's happening.
      document.fire 'viewer:set-active-post',
        post_id: @displayed_post_id
        post_frame: item.post_frame
        center_thumbs: true

    # We'll receive this message from the thumbnail view when the overlay is
    # visible on the bottom of the screen, to tell us how much space is covered up
    # by it.
    @thumb_bar_height = 0
    document.on 'viewer:thumb-bar-changed', (e) =>
      # Update the thumb bar height and rescale the image to fit the new area.
      @thumb_bar_height = e.memo.height
      @update_image_window_size()
      @set_post_ui e.memo.shown
      @scale_and_position_image true

    ###
      OnKey(79, null, function(e) {
        this.zoom_level -= 1;
        this.scale_and_position_image(true);
        this.update_navigator();
        return true;
      }.bindAsEventListener(this));

      OnKey(80, null, function(e) {
        this.zoom_level += 1;
        this.scale_and_position_image(true);
        this.update_navigator();
        return true;
      }.bindAsEventListener(this));
    ###

    # Hide member-only and moderator-only controls:
    $(document.body).pickClassName 'is-member', 'not-member', User.is_member_or_higher()
    $(document.body).pickClassName 'is-moderator', 'not-moderator', User.is_mod_or_higher()
    tag_span = @container.down('.post-tags')
    tag_span.on 'click', '.post-tag', (e, element) ->
      e.stop()
      document.fire 'viewer:perform-search', tags: element.tag_name

    # These two links do the same thing, but one is shown to approve a pending post
    # and the other is shown to unflag a flagged post, so they prompt differently.
    @container.down('.post-approve').on 'click', (e) =>
      e.stop()
      if !confirm('Approve this post?')
        return
      post_id = @displayed_post_id
      Post.approve post_id, false

    @container.down('.post-unflag').on 'click', (e) =>
      e.stop()
      if !confirm('Unflag this post?')
        return
      post_id = @displayed_post_id
      Post.unflag post_id

    @container.down('.post-delete').on 'click', (e) =>
      e.stop()
      post = Post.posts.get(@displayed_post_id)
      default_reason = ''
      if post.flag_detail
        default_reason = post.flag_detail.reason
      reason = prompt('Reason:', default_reason)
      if !reason or reason == ''
        return
      post_id = @displayed_post_id
      Post.approve post_id, reason

    @container.down('.post-undelete').on 'click', (e) =>
      e.stop()
      if !confirm('Undelete this post?')
        return
      post_id = @displayed_post_id
      Post.undelete post_id

    @container.down('.flag-button').on 'click', (e) =>
      e.stop()
      post_id = @displayed_post_id
      Post.flag post_id

    @container.down('.activate-post').on 'click', (e) =>
      e.stop()
      post_id = @displayed_post_id
      return if !confirm('Activate this post?')
      Post.update_batch [{
        id: post_id
        is_held: false
      }], ->
        post = Post.posts.get(post_id)
        if post.is_held
          notice "Couldn't activate post"
        else
          notice 'Activated post'

    @container.down('.reparent-post').on 'click', (e) =>
      e.stop()
      return if !confirm('Make this post the parent?')
      post_id = @displayed_post_id
      post = Post.posts.get(post_id)
      return if !post?
      Post.reparent_post post_id, post.parent_id, false

    @container.down('.pool-info').on 'click', '.remove-pool-from-post', (e, element) ->
      e.stop()
      pool_info = element.up('.pool-info')
      pool = Pool.pools[pool_info.pool_id]
      pool_name = pool.name.replace(/_/g, ' ')
      return if !confirm("Remove this post from pool ##{pool_info.pool_id}: #{pool_name}?")
      Pool.remove_post pool_info.post_id, pool_info.pool_id

    # Post editing:
    post_edit = @container.down('.post-edit')
    post_edit.down('FORM').on 'submit', (e) =>
      e.stop()
      @edit_save()

    @container.down('.show-tag-edit').on 'click', (e) =>
      e.stop()
      @edit_show true

    @container.down('.edit-save').on 'click', (e) =>
      e.stop()
      @edit_save()

    @container.down('.edit-cancel').on 'click', (e) =>
      e.stop()
      @edit_show false

    post_edit.down('.edit-tags').on 'paste', => @edit_post_area_changed.defer()
    post_edit.down('.edit-tags').on 'keydown', => @edit_post_area_changed.defer()

    new TagCompletionBox(post_edit.down('.edit-tags'))
    @container.down('.post-edit').on 'keydown', (e) =>
      # Don't e.stop() KEY_ESC, so we fall through and let handle_keypress unfocus the
      # form entry, if any.  Otherwise, Chrome gets confused and leaves the focus on the
      # hidden input, where it'll steal keystrokes.
      if e.keyCode == Event.KEY_ESC
        @edit_show false
      else if e.keyCode == Event.KEY_RETURN
        e.stop()
        @edit_save()

    # When the edit-post hotkey is pressed (E), force the post UI open and show editing.
    document.on 'viewer:edit-post', (e) =>
      document.fire 'viewer:set-thumb-bar', set: true
      @edit_show true

    # When the post that's currently being displayed is updated by an API call, update
    # the displayed info.
    document.on 'posts:update', (e) =>
      return if !e.memo.post_ids.get(@displayed_post_id)?
      @set_post_info()

    @vote_widget = new Vote(jQuery(@container.down('.vote-container'), null))
    @vote_widget.initShortcut()
    @blacklist_override_post_id = null

    @container.down('.show-blacklisted').on 'click', (e) =>
      e.preventDefault()

    @container.down('.show-blacklisted').on 'dblclick', (e) =>
      e.stop()
      @blacklist_override_post_id = @displayed_post_id
      post = Post.posts.get(@displayed_post_id)
      @set_main_image post, @displayed_post_frame

    @img_box.on 'viewer:center-on', (e) =>
      @center_image_on e.memo.x, e.memo.y

    @navigator = new Navigator(@container.down('.image-navigator'), @img_box)
    @container.on 'swipe:horizontal', (e) =>
      document.fire 'viewer:show-next-post', prev: e.memo.right

    if Prototype.BrowserFeatures.Touchscreen
      @create_voting_popup()
      @image_swipe = new SwipeHandler(@container.down('.image-container'))

    # Create the frame editor.  This must be created before image_dragger, since it takes priority
    # for drags.
    @container.down('.edit-frames-button').on 'click', (e) =>
      e.stop()
      @show_frame_editor()

    @frame_editor = new FrameEditor(@container.down('.frame-editor'), @img_box, @container.down('.frame-editor-popup'), onClose: => @hide_frame_editor())

    # If we're using dragging as a swipe gesture (see SwipeHandler), don't use it for
    # dragging too.
    @image_dragger = new WindowDragElementAbsolute(@img_box, @update_navigator) if !@image_swipe?


  create_voting_popup: ->
    # Create the low-level voting widget.
    popup_vote_widget_container = @container.down('.vote-popup-container')
    popup_vote_widget_container.show()
    @popup_vote_widget = new Vote(jQuery(popup_vote_widget_container), null)
    @popup_vote_widget.initShortcut()
    flash = @container.down('.vote-popup-flash')

    # vote-popup-expand is the part that's always present and is clicked to display the
    # voting popup.  Create a dragger on it, and pass the position down to the voting
    # popup as we drag around.
    popup_expand = @container.down('.vote-popup-expand')
    popup_expand.show()
    last_dragged_over = null
    @popup_vote_dragger = new DragElement(
      popup_expand,
      ondown: (drag) =>
        # Stop the touchdown/mousedown events, so this drag takes priority over any
        # others.  In particular, we don't want this.image_swipe to also catch this
        # as a drag.
        drag.latest_event.stop()
        flash.hide()
        flash.removeClassName 'flash-star'
        @popup_vote_widget.set_mouseover null
        last_dragged_over = null
        popup_vote_widget_container.removeClassName 'vote-popup-hidden'
      onup: (drag) =>
        # If we're cancelling the drag, don't activate the vote, if any.
        if drag.cancelling
          debug 'cancelling drag'
          last_dragged_over = null

        # Call even if star_container is null or not a star, so we clear any mouseover.
        @popup_vote_widget.set_mouseover last_dragged_over
        star = @popup_vote_widget.activate_item(last_dragged_over)

        # If a vote was made, flash the vote star.
        if star?
          # Set the star-# class to color the star.
          i = 0
          while i < 4
            flash.removeClassName "star-#{i}"
            ++i
          flash.addClassName "star-#{star}"
          flash.show()

          # Center the element on the screen.
          offset = @image_window_size
          flash_x = offset.width / 2 - (flash.offsetWidth / 2)
          flash_y = offset.height / 2 - (flash.offsetHeight / 2)
          flash.setStyle
            left: flash_x + 'px'
            top: flash_y + 'px'
          flash.addClassName 'flash-star'
        popup_vote_widget_container.addClassName 'vote-popup-hidden'
        last_dragged_over = null
      ondrag: (drag) =>
        last_dragged_over = document.elementFromPoint(drag.x, drag.y)
        @popup_vote_widget.set_mouseover last_dragged_over
    )


  set_post_ui: (visible) ->
    # Disable the post UI by default on touchscreens; we don't have an interface
    # to toggle it.
    if Prototype.BrowserFeatures.Touchscreen && window.screen.availWidth < 1024
      visible = false

    # If we don't have a post displayed, always hide the post UI even if it's currently
    # shown.
    @container.down('.post-info').show(visible) && @displayed_post_id?
    return if visible == @post_ui_visible
    @post_ui_visible = visible
    if @navigator
      @navigator.set_autohide !visible

    # If we're hiding the post UI, cancel the post editor if it's open.
    @edit_show false if !@post_ui_visible

  image_loaded_event: (event) =>
    # Record that the image is completely available, so it can be blitted to the canvas.
    # This is different than img.complete, which is true if the image has completed downloading
    # but hasn't yet been decoded, so isn't yet completely available.  This generally happens
    # if we query img.completed quickly after setting img.src and the image data is cached.
    @img.fully_loaded = true
    document.fire 'viewer:displayed-image-loaded',
      post_id: @displayed_post_id
      post_frame: @displayed_post_frame
    @update_canvas()


  # Return true if last_preload_request includes [post_id, post_frame].
  post_frame_list_includes: (post_id_list, post_id, post_frame) ->
    found_preload = post_id_list.find (post) ->
      post[0] == post_id && post[1] == post_frame

    found_preload?


  # Begin preloading the HTML and images for the given post IDs.
  preload: (post_ids) ->
    # We're being asked to preload post_ids.  Only do this if it seems to make sense: if
    # the user is actually traversing posts that are being preloaded.  Look at the previous
    # call to preload().  If it didn't include the current post, then skip the preload.
    last_preload_request = @last_preload_request
    @last_preload_request = post_ids
    if !@post_frame_list_includes(last_preload_request, @wanted_post_id, @wanted_post_frame)
      # debug("skipped-preload(" + post_ids.join(",") + ")");
      @last_preload_request_active = false
      return
    @last_preload_request_active = true
    # debug("preload(" + post_ids.join(",") + ")");
    new_preload_container = new PreloadContainer
    i = 0
    while i < post_ids.length
      post_id = post_ids[i][0]
      post_frame = post_ids[i][1]
      post = Post.posts.get(post_id)
      if post_frame != -1
        frame = post.frames[post_frame]
        new_preload_container.preload frame.url
      else
        new_preload_container.preload post.sample_url
      ++i

    # If we already were preloading images, we created the new preloads before
    # deleting the old ones.  That way, any images that are still being preloaded
    # won't be deleted and recreated, possibly causing the download to be interrupted
    # and resumed.
    @preload_container?.destroy()
    @preload_container = new_preload_container


  load_post_id_data: (post_id) ->
    debug 'load needed'
    # If we already have a request in flight, don't start another; wait for the
    # first to finish.
    return if @current_ajax_request?

    ok = false
    @current_ajax_request = jQuery.ajax
      url: '/post.json'
      method: 'get'
      dataType: 'json'
      data:
        tags: "id:#{post_id}"
        api_version: 2
        filter: 1
        include_tags: 1
        include_votes: 1
        include_pools: 1
    .done (resp) =>
      # If no posts were returned, then the post ID we're looking up doesn't exist;
      # treat this as a failure.
      ok = true
      @success = resp.posts.length > 0
      if !@success
        notice "Post ##{post_id} doesn't exist"
        return
      Post.register_resp resp
    .always (resp) =>
      @current_ajax_request = null

      # If the request failed and we were requesting wanted_post_id, don't keep trying.
      success = ok && @success
      if !success && post_id == @wanted_post_id
        # As a special case, if the post we requested doesn't exist and we aren't displaying
        # anything at all, force the thumb bar open so we don't show nothing at all.
        if !@displayed_post_id?
          document.fire 'viewer:set-thumb-bar', set: true
        return

      # This will either load the post we just finished, or request data for the
      # one we want.
      @set_post @wanted_post_id, @wanted_post_frame
    .fail (resp) -> notice "Error #{resp.status} loading post"


  set_viewing_larger_version: (b) ->
    @viewing_larger_version = b
    post = Post.posts.get(@displayed_post_id)
    can_zoom = post? && post.jpeg_url != post.sample_url
    @container.down('.zoom-icon-none').show(!can_zoom)
    @container.down('.zoom-icon-in').show(can_zoom && !@viewing_larger_version)
    @container.down('.zoom-icon-out').show(can_zoom && @viewing_larger_version)

    # When we're on the regular version and we're on a touchscreen, disable drag
    # scrolling so we can use it to switch images instead.
    if Prototype.BrowserFeatures.Touchscreen and @image_dragger
      @image_dragger.set_disabled !b

    # Only allow dragging to create new frames when not viewing the large version,
    # since we need to be able to drag the image.
    if @frame_editor
      @frame_editor.set_drag_to_create !b
      @frame_editor.set_show_corner_drag !b

  set_main_image: (post, post_frame) ->
    ###
    # Clear the previous post, if any.  Don't keep the old IMG around; create a new one, or
    # we may trigger long-standing memory leaks in WebKit, eg.:
    # https://bugs.webkit.org/show_bug.cgi?id=31253
    #
    # This also helps us avoid briefly displaying the old image with the new dimensions, which
    # can otherwise take some hoop jumping to prevent.
    ###
    if @img?
      @img.stopObserving()
      @img.parentNode.removeChild @img
      @image_pool.release @img
      @img = null

    # If this post is blacklisted, show a message instead of displaying it.

    hide_post = Post.is_blacklisted(post.id) && post.id != @blacklist_override_post_id
    @container.down('.blacklisted-message').show hide_post
    if hide_post
      return
    @img = @image_pool.get()
    @img.className = 'main-image'
    if @canvas
      @canvas.hide()
    @img.show()

    ###
    # Work around an iPhone bug.  If a touchstart event is sent to this.img, and then
    # (due to a swipe gesture) we remove the image and replace it with a new one, no
    # touchend is ever delivered, even though it's the containing box listening to the
    # event.  Work around this by setting the image to pointer-events: none, so clicks on
    # the image will actually be sent to the containing box directly.
    ###
    @img.setStyle pointerEvents: 'none'
    @img.on 'load', @image_loaded_event
    @img.fully_loaded = false
    if post_frame != -1 && post_frame < post.frames.length
      frame = post.frames[post_frame]
      @img.src = frame.url
      @img_box.original_width = frame.width
      @img_box.original_height = frame.height
      @img_box.show()
    else if @viewing_larger_version && post.jpeg_url
      @img.src = post.jpeg_url
      @img_box.original_width = post.jpeg_width
      @img_box.original_height = post.jpeg_height
      @img_box.show()
    else if !@viewing_larger_version && post.sample_url
      @img.src = post.sample_url
      @img_box.original_width = post.sample_width
      @img_box.original_height = post.sample_height
      @img_box.show()
    else
      # Having no sample URL is an edge case, usually from deleted posts.  Keep the number
      # of code paths smaller by creating the IMG anyway, but not showing it.
      @img_box.hide()
    @container.down('.image-box').appendChild @img
    if @viewing_larger_version
      @navigator.set_image post.preview_url, post.actual_preview_width, post.actual_preview_height
      @navigator.set_autohide !@post_ui_visible
    @navigator.enable @viewing_larger_version
    @scale_and_position_image()


  ###
  # Display post_id.  If post_frame is not null, set the specified frame.
  #
  # If no_hash_change is true, the UrlHash will not be updated to reflect the new post.
  # This should be used when this is called to load the post already reflected by the
  # URL hash.  For example, the hash "#/pool:123" shows pool 123 in the thumbnails and
  # shows its first post in the view.  It should *not* change the URL hash to reflect
  # the actual first post (eg. #12345/pool:123).  This will insert an unwanted history
  # state in the browser, so the user has to go back twice to get out.
  #
  # no_hash_change should also be set when loading a state as a result of hashchange,
  # for similar reasons.
  ###
  set_post: (post_id, post_frame, lazy, no_hash_change, replace_history) ->
    throw 'post_id must not be null' if !post_id?

    # If there was a lazy load pending, cancel it.
    @cancel_lazily_load()
    @wanted_post_id = post_id
    @wanted_post_frame = post_frame
    @wanted_post_no_hash_change = no_hash_change
    @wanted_post_replace_history = replace_history
    return if post_id == @displayed_post_id && post_frame == @displayed_post_frame

    # If a lazy load was requested and we're not yet loading the image for this post,
    # delay loading.
    is_cached = @last_preload_request_active && @post_frame_list_includes(@last_preload_request, post_id, post_frame)
    if lazy && !is_cached
      @lazy_load_timer = window.setTimeout((=>
        @lazy_load_timer = null
        @set_post @wanted_post_id, @wanted_post_frame, false, @wanted_post_no_hash_change, @wanted_post_replace_history
      ), 500)
      return

    @hide_frame_editor()
    post = Post.posts.get(post_id)
    if !post?
      # The post we've been asked to display isn't loaded.  Request a load and come back.
      if !@displayed_post_id?
        @container.down('.post-info').hide()
      @load_post_id_data post_id
      return

    if !post_frame?
      # If post_frame is unspecified and we have a frame, display the first.
      post_frame = @get_default_post_frame(post_id)
      # We know what frame we actually want to display now, so update wanted_post_frame.
      @wanted_post_frame = post_frame

    # If post_frame doesn't exist, just display the main post.
    if post_frame != -1 and post.frames.length <= post_frame
      post_frame = -1
    @displayed_post_id = post_id
    @displayed_post_frame = post_frame
    if !no_hash_change
      post_frame_hash = @get_post_frame_hash(post, post_frame)
      UrlHash.set_deferred {
        'post-id': post_id
        'post-frame': post_frame_hash
      }, replace_history
    @set_viewing_larger_version false
    @set_main_image post, post_frame
    if @vote_widget
      if @vote_widget.post_id
        Post.votes.set @vote_widget.post_id, @vote_widget.data.vote
        Post.posts.get(@vote_widget.post_id).score = @vote_widget.data.score
      @vote_widget.post_id = post.id
      @vote_widget.updateWidget Post.votes.get(post.id), post.score
    if @popup_vote_widget
      @popup_vote_widget.post_id = post.id
      @popup_vote_widget.updateWidget Post.votes.get(post.id), post.score
    document.fire 'viewer:displayed-post-changed',
      post_id: post_id
      post_frame: post_frame
    @set_post_info()

    # Hide the editor when changing posts.
    @edit_show false


  ###
  # Return the frame spec for the hash, eg. "-0".
  #
  # If the post has no frames, then just omit the frame spec.  If the post has any frames,
  # then return the frame number or "-F" for the full image.
  ###
  post_frame_hash: (post, post_frame) ->
    return '' if post.frames.length == 0
    '-' + (if post_frame == -1 then 'F' else post_frame)

  ###
  # Return the default frame to display for the given post.  If the post isn't loaded,
  # we don't know which frame we'll display and null will be returned.  This corresponds
  # to a hash of #1234, where no frame is specified (eg. #1234-F, #1234-0).
  ###
  get_default_post_frame: (post_id) ->
    post = Post.posts.get(post_id)
    if !post?
      return null
    if post.frames.length > 0 then 0 else -1

  get_post_frame_hash: (post, post_frame) ->
    ###
    # Omitting the frame in the hash selects the default frame: the first frame if any,
    # otherwise the full image.  If we're setting the hash to a post_frame which would be
    # selected by this default, omit the frame so this default is used.  For example, if
    # post #1234 has one frame and post_frame is 0, it would be selected by the default,
    # so omit the frame and use a hash of #1234, not #1234-0.
    #
    # This helps normalize the hash.  Otherwise, loading /#1234 will update the hash to
    # /#1234-in set_post, causing an unwanted history entry.
    ###
    default_frame = if post.frames.length > 0 then 0 else -1
    if post_frame == default_frame
      null
    else
      post_frame


  # Set the post info box for the currently displayed post.
  set_post_info: ->
    post = Post.posts.get(@displayed_post_id)
    return if !post
    @container.down('.post-id').setTextContent post.id
    @container.down('.post-id-link').href = '/post/show/' + post.id
    @container.down('.posted-by').show()
    @container.down('.posted-at').setTextContent time_ago_in_words(new Date(post.created_at * 1000))

    # Fill in the pool list.
    pool_info = @container.down('.pool-info')
    while pool_info.firstChild
      pool_info.removeChild pool_info.firstChild
    if post.pool_posts
      post.pool_posts.each (pp) ->
        pool_post = pp[1]
        pool_id = pool_post.pool_id
        pool = Pool.pools[pool_id]
        pool_title = pool.name.replace(/_/g, ' ')
        sequence = pool_post.sequence
        if sequence.match(/^[0-9]/)
          sequence = '#' + sequence
        html = '<div class="pool-info">Post ${sequence} in <a class="pool-link" href="/post/browse#/pool:${pool_id}">${desc}</a> ' + '(<a target="_blank" href="/pool/show/${pool_id}">pool page</a>)'
        if Pool.can_edit_pool(pool)
          html += '<span class="advanced-editing"> (<a href="#" class="remove-pool-from-post">remove</a>)</div></span>'
        div = html.subst(
          sequence: sequence
          pool_id: pool_id
          desc: pool_title.escapeHTML()).createElement()
        div.post_id = post.id
        div.pool_id = pool_id
        pool_info.appendChild div

    if post.creator_id?
      @container.down('.posted-by').down('A').href = "/user/show/#{post.creator_id}"
      @container.down('.posted-by').down('A').setTextContent post.author
    else
      @container.down('.posted-by').down('A').href = '#'
      @container.down('.posted-by').down('A').setTextContent 'Anonymous'
    @container.down('.post-dimensions').setTextContent post.width + 'x' + post.height
    @container.down('.post-source').show post.source != ''
    if post.source != ''
      text = post.source
      url = null
      # pixiv URL with artist user id info (up to 2014)
      m_old = post.source.match(/^http:\/\/.*pixiv\.net\/(img\d+\/)?img\/([-\w]+)\/(\d+)(_.+)?\.\w+$/)
      # pixiv URL without artist user id info (2014+)
      m = post.source.match(/^https?:\/\/.*(?:pixiv\.net|pximg\.net)\/img.*?(\d+)(_s|_m|(_big)?_p\d+)?\.\w+(\?\d+)?$/)
      if m_old
        text = "pixiv ##{m_old[3]} (#{m_old[2]})"
        url = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{m_old[3]}"
      else if m
        text = "pixiv ##{m[1]}"
        url = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{m[1]}"
      else if post.source.substr(0, 7) == 'http://'
        text = text.substr(7)
        if text.substr(0, 4) == 'www.'
          text = text.substr(4)
        if text.length > 20
          text = text.substr(0, 20) + '...'
        url = post.source
      source_box = @container.down('.post-source')
      source_box.down('A').show url?
      source_box.down('SPAN').show !url?
      if url
        source_box.down('A').href = url
        source_box.down('A').setTextContent text
      else
        source_box.down('SPAN').setTextContent text
    if post.frames.length > 0
      # Hide this with a class rather than by changing display, so show_frame_editor
      # and hide_frame_editor can hide and unhide this separately.
      @container.down('.post-frames').removeClassName 'no-frames'
      frame_list = @container.down('.post-frame-list')
      while frame_list.firstChild
        frame_list.removeChild frame_list.firstChild
      i = -1
      while i < post.frames.length
        text = if i == -1 then 'main' else i + 1
        a = document.createElement('a')
        a.href = '/post/browse#' + post.id + @post_frame_hash(post, i)
        a.className = 'post-frame-link'
        if @displayed_post_frame == i
          a.className += ' current-post-frame'
        a.setTextContent text
        a.post_frame = i
        frame_list.appendChild a
        ++i
    else
      @container.down('.post-frames').addClassName 'no-frames'
    ratings =
      s: 'Safe'
      q: 'Questionable'
      e: 'Explicit'
    @container.down('.post-rating').setTextContent ratings[post.rating]
    @container.down('.post-score').setTextContent post.score
    @container.down('.post-hidden').show !post.is_shown_in_index
    @container.down('.post-info').show @post_ui_visible

    file_extension = (path) ->
      m = path.match(/.*\.([^.]+)/)
      return '' if !m
      m[1]

    has_sample = post.sample_url != post.file_url
    has_jpeg = post.jpeg_url != post.file_url
    has_image = post.file_url? and !has_sample

    # Hide the whole download-links box if there are no downloads available, usually
    # because of a deleted post.
    @container.down('.download-links').show has_image or has_sample or has_jpeg
    @container.down('.download-image').show has_image
    if has_image
      @container.down('.download-image').href = post.file_url
      @container.down('.download-image-desc').setTextContent number_to_human_size(post.file_size) + ' ' + file_extension(post.file_url.toUpperCase())
    @container.down('.download-jpeg').show has_sample
    if has_sample
      @container.down('.download-jpeg').href = if has_jpeg then post.jpeg_url else post.file_url
      image_desc = number_to_human_size(if has_jpeg then post.jpeg_file_size else post.file_size) + ' JPG'
      @container.down('.download-jpeg-desc').setTextContent image_desc
    @container.down('.download-png').show has_jpeg
    if has_jpeg
      @container.down('.download-png').href = post.file_url
      png_desc = number_to_human_size(post.file_size) + ' ' + file_extension(post.file_url.toUpperCase())
      @container.down('.download-png-desc').setTextContent png_desc

    # For links that are handled by click events, try to set the href so that copying the
    # link will give a similar effect.  For example, clicking parent-post will call set_post
    # to display it, and the href links to /post/browse#12345.
    parent_post = @container.down('.parent-post')
    parent_post.show post.parent_id?
    if post.parent_id
      parent_post.down('A').href = '/post/browse#' + post.parent_id
    child_posts = @container.down('.child-posts')
    child_posts.show post.has_children
    if post.has_children
      child_posts.down('A').href = '/post/browse#/parent:' + post.id

    # Create the tag links.
    tag_span = @container.down('.post-tags')
    first = true
    while tag_span.firstChild
      tag_span.removeChild tag_span.firstChild
    tags_by_type = Post.get_post_tags_with_type(post)
    tags_by_type.each (t) ->
      tag = t[0]
      type = t[1]
      span = $(document.createElement('SPAN', ''))
      span = $(span)
      span.className = 'tag-type-' + type
      space = document.createTextNode(' ')
      span.appendChild space
      a = jQuery('<a>',
        text: tag
        href: '/post/browse#/' + tag
        class: 'post-tag tag-type-' + type)

      # Break tags with <wbr>, so long tags can be wrapped.
      a.html a.html().replace(/_/g, '_<wbr>')

      # convert back to something Prototype or whatever can understand
      a = a[0]
      a.tag_name = tag
      span.appendChild a
      tag_span.appendChild span
      return
    flag_post = @container.down('.flag-button')
    flag_post.show post.status == 'active'
    @container.down('.post-approve').show post.status == 'flagged' or post.status == 'pending'
    @container.down('.post-delete').show post.status != 'deleted'
    @container.down('.post-undelete').show post.status == 'deleted'
    flagged = @container.down('.flagged-info')
    flagged.show post.status == 'flagged'
    if post.status == 'flagged' and post.flag_detail
      byEl = flagged.down('.by')
      flagged.down('.flagged-by-box').show post.flag_detail.user_id?
      if post.flag_detail.user_id?
        byEl.setTextContent post.flag_detail.flagged_by
        byEl.href = '/user/show/' + post.flag_detail.user_id
      reason = flagged.down('.reason')
      reason.setTextContent post.flag_detail.reason

    # Moderators can unflag images, and the person who flags an image can unflag it himself.
    is_flagger = post.flag_detail and post.flag_detail.user_id == User.get_current_user_id()
    can_unflag = flagged and (User.is_mod_or_higher() or is_flagger)
    flagged.down('.post-unflag').show can_unflag
    pending = @container.down('.status-pending')
    pending.show post.status == 'pending'
    @container.down('.pending-reason-box').show post.flag_detail and post.flag_detail.reason
    if post.flag_detail
      @container.down('.pending-reason').setTextContent post.flag_detail.reason
    deleted = @container.down('.status-deleted')
    deleted.show post.status == 'deleted'
    if post.status == 'deleted'
      by_container = deleted.down('.by-container')
      by_container.show post.flag_detail.flagged_by?
      byEl = by_container.down('.by')
      byEl.setTextContent post.flag_detail.flagged_by
      byEl.href = '/user/show/' + post.flag_detail.user_id
      reason = deleted.down('.reason')
      reason.setTextContent post.flag_detail.reason
    @container.down('.status-held').show post.is_held
    has_permission = User.get_current_user_id() == post.creator_id or User.is_mod_or_higher()
    @container.down('.activate-post').show has_permission
    return

  edit_show: (shown) ->
    post = Post.posts.get(@displayed_post_id)
    if !post
      shown = false
    if !User.is_member_or_higher()
      shown = false
    @edit_shown = shown
    @container.down('.post-tags-box').show !shown
    @container.down('.post-edit').show shown
    if !shown
      # Revert all changes.
      @frame_editor.discard()
      return
    @select_edit_box '.post-edit-main'

    # This returns [tag, tag type].  We only want the tag; we call this so we sort the
    # tags consistently.
    tags_by_type = Post.get_post_tags_with_type(post)
    tags = tags_by_type.pluck(0)
    tags = tags.join(' ') + ' '
    @container.down('.edit-tags').old_value = tags
    @container.down('.edit-tags').value = tags
    @container.down('.edit-source').value = post.source
    @container.down('.edit-parent').value = post.parent_id
    @container.down('.edit-shown-in-index').checked = post.is_shown_in_index
    rating_class = new Hash(
      s: '.edit-safe'
      q: '.edit-questionable'
      e: '.edit-explicit')
    @container.down(rating_class.get(post.rating)).checked = true
    @edit_post_area_changed()
    @container.down('.edit-tags').focus()


  # Set the size of the tag edit area to the size of its contents.
  edit_post_area_changed: =>
    post_edit = @container.down('.post-edit')
    element = post_edit.down('.edit-tags')
    element.style.height = '0px'
    element.style.height = element.scrollHeight + 'px'
    if 0
      rating = null
      source = null
      parent_id = null
      element.value.split(' ').each ((tag) ->
        # This mimics what the server side does; it does prevent metatags from using
        # uppercase in source: metatags.
        tag = tag.toLowerCase()

        # rating:q or just q:
        m = tag.match(/^(rating:)?([qse])$/)
        if m
          rating = m[2]
          return
        m = tag.match(/^(parent):([0-9]+)$/)
        if m
          if m[1] == 'parent'
            parent_id = m[2]
        m = tag.match(/^(source):(.*)$/)
        if m
          if m[1] == 'source'
            source = m[2]
        return
      ).bind(this)
      debug 'rating: ' + rating
      debug 'source: ' + source
      debug 'parent: ' + parent_id
    return

  edit_save: ->
    save_completed = (->
      notice 'Post saved'

      # If we're still showing the post we saved, hide the edit area.
      if @displayed_post_id == post_id
        @edit_show false
      return
    ).bind(this)
    post_id = @displayed_post_id

    # If we're in the frame editor, save it.  Don't save the hidden main editor.
    if @frame_editor
      if @frame_editor.is_opened()
        @frame_editor.save save_completed
        return
    edit_tags = @container.down('.edit-tags')
    tags = edit_tags.value

    # Opera doesn't blur the field automatically, even when we hide it later.
    edit_tags.blur()

    # Find which rating is selected.
    rating_class = new Hash(
      s: '.edit-safe'
      q: '.edit-questionable'
      e: '.edit-explicit')
    selected_rating = 's'
    rating_class.each (c) =>
      selected_rating = c[0] if @container.down(c[1]).checked

    # update_batch will give us updates for any related posts, as well as the one we're
    # updating.
    Post.update_batch [ {
      id: post_id
      tags: @container.down('.edit-tags').value
      old_tags: @container.down('.edit-tags').old_value
      source: @container.down('.edit-source').value
      parent_id: @container.down('.edit-parent').value
      is_shown_in_index: @container.down('.edit-shown-in-index').checked
      rating: selected_rating
    } ], save_completed
    return

  window_resize_event: (e) =>
    return if e.stopped

    @update_image_window_size()
    @scale_and_position_image true


  toggle_view_large_image: =>
    post = Post.posts.get(@displayed_post_id)

    return if !post?
    return if !@img?

    # There's no larger version to display.
    return if post.jpeg_url == post.sample_url

    # Toggle between the sample and JPEG version.
    @set_viewing_larger_version !@viewing_larger_version
    @set_main_image post
    # XXX frame
    return


  # this.image_window_size is the size of the area where the image is visible.
  update_image_window_size: ->
    @image_window_size = getWindowSize()

    # If the thumb bar is shown, exclude it from the window height and fit the image
    # in the remainder.  Since the bar is at the bottom, we don't need to do anything to
    # adjust the top.
    @image_window_size.height -= @thumb_bar_height
    # clamp to 0 if there's no space
    @image_window_size.height = Math.max(@image_window_size.height, 0)

    # When the window size changes, update the navigator since the cursor will resize to
    # match.
    @update_navigator()
    return

  scale_and_position_image: (resizing) ->
    img_box = @img_box
    if !@img
      return
    original_width = img_box.original_width
    original_height = img_box.original_height
    post = Post.posts.get(@displayed_post_id)
    if !post
      debug 'unexpected: displayed post ' + @displayed_post_id + ' unknown'
      return
    window_size = @image_window_size
    ratio = 1.0
    if !@viewing_larger_version
      # Zoom the image to fit the viewport.
      ratio = window_size.width / original_width
      if original_height * ratio > window_size.height
        ratio = window_size.height / original_height
    ratio *= 0.9 ** @zoom_level
    @displayed_image_width = Math.round(original_width * ratio)
    @displayed_image_height = Math.round(original_height * ratio)
    @img.width = @displayed_image_width
    @img.height = @displayed_image_height
    @update_canvas()
    if @frame_editor
      @frame_editor.set_image_dimensions @displayed_image_width, @displayed_image_height

    # If we're resizing and showing the full-size image, don't snap the position
    # back to the default.
    if resizing and @viewing_larger_version
      return
    x = 0.5
    y = 0.5
    if @viewing_larger_version
      # Align the image to the top of the screen.
      y = @image_window_size.height / 2
      y /= @displayed_image_height
    @center_image_on x, y
    return

  # x and y are [0,1].
  update_navigator: =>
    return if !@navigator
    return if !@img

    # The coordinates of the image located at the top-left corner of the window:
    scroll_x = -@img_box.offsetLeft
    scroll_y = -@img_box.offsetTop

    # The coordinates at the center of the window:
    x = scroll_x + @image_window_size.width / 2
    y = scroll_y + @image_window_size.height / 2
    percent_x = x / @displayed_image_width
    percent_y = y / @displayed_image_height
    height_percent = @image_window_size.height / @displayed_image_height
    width_percent = @image_window_size.width / @displayed_image_width
    @navigator.image_position_changed percent_x, percent_y, height_percent, width_percent
    return

  ###
  # If Canvas support is available, we can accelerate drawing.
  #
  # Most browsers are slow when resizing large images.  In the best cases, it results in
  # dragging the image around not being smooth (all browsers except Chrome).  In the worst
  # case it causes rendering the page to be very slow; in Chrome, drawing the thumbnail
  # strip under a large resized image is unusably slow.
  #
  # If Canvas support is enabled, then once the image is fully loaded, blit the image into
  # the canvas at the size we actually want to display it at.  This avoids most scaling
  # performance issues, because it's not rescaling the image constantly while dragging it
  # around.
  #
  # Note that if Chrome fixes its slow rendering of boxes *over* the image, then this may
  # be unnecessary for that browser.  Rendering the image itself is very smooth; Chrome seems
  # to prescale the image just once, which is what we're doing.
  #
  # Limitations:
  # - If full-page zooming is being used, it'll still scale at runtime.
  # - We blit the entire image at once.  It's more efficient to blit parts of the image
  #   as necessary to paint, but that's a lot more work.
  # - Canvas won't blit partially-loaded images, so we do nothing until the image is complete.
  ###
  update_canvas: ->
    if !@img.fully_loaded
      debug "image incomplete; can't render to canvas"
      return false
    if !@canvas
      return

    # If the contents havn't changed, skip the blit.  This happens frequently when resizing
    # the window when not fitting the image to the screen.
    if @canvas.rendered_url == @img.src and @canvas.width == @displayed_image_width and @canvas.height == @displayed_image_height
      # debug(this.canvas.rendered_url + ", " + this.canvas.width + ", " + this.canvas.height)
      # debug("Skipping canvas blit");
      return
    @canvas.rendered_url = @img.src
    @canvas.width = @displayed_image_width
    @canvas.height = @displayed_image_height
    ctx = @canvas.getContext('2d')
    ctx.drawImage @img, 0, 0, @displayed_image_width, @displayed_image_height
    @canvas.show()
    @img.hide()
    true

  center_image_on: (percent_x, percent_y) ->
    x = percent_x * @displayed_image_width
    y = percent_y * @displayed_image_height
    scroll_x = x - (@image_window_size.width / 2)
    scroll_x = Math.round(scroll_x)
    scroll_y = y - (@image_window_size.height / 2)
    scroll_y = Math.round(scroll_y)
    @img_box.setStyle
      left: -scroll_x + 'px'
      top: -scroll_y + 'px'
    @update_navigator()
    return

  cancel_lazily_load: ->
    if !@lazy_load_timer?
      return
    window.clearTimeout @lazy_load_timer
    @lazy_load_timer = null
    return

  parent_post_click_event: (event) =>
    event.stop()
    post = Post.posts.get(@displayed_post_id)
    if !post? || !post.parent_id?
      return
    @set_post post.parent_id
    return

  child_posts_click_event: (event) =>
    event.stop()

    # Search for this post's children.  Set the results mode to center-on-current, so we
    # focus on the current item.
    document.fire 'viewer:perform-search',
      tags: 'parent:' + @displayed_post_id
      results_mode: 'center-on-current'
    return

  select_edit_box: (className) ->
    if @shown_edit_container
      @shown_edit_container.hide()
    @shown_edit_container = @container.down(className)
    @shown_edit_container.show()
    return

  show_frame_editor: ->
    @select_edit_box '.frame-editor'

    # If we're displaying a frame and not the whole image, switch to the main image.
    post_frame = null
    if @displayed_post_frame != -1
      post_frame = @displayed_post_frame
      document.fire 'viewer:set-active-post',
        post_id: @displayed_post_id
        post_frame: -1
    @frame_editor.open @displayed_post_id
    @container.down('.post-frames').hide()

    # If we were on a frame when opened, focus the frame we were on.  Otherwise,
    # leave it on the default.
    if post_frame?
      @frame_editor.focus post_frame
    return

  hide_frame_editor: ->
    @frame_editor.discard()
    @container.down('.post-frames').show()
    return


# Update the window title when the display changes.
class window.WindowTitleHandler
  constructor: ->
    @searched_tags = ''
    @post_id = null
    @post_frame = null
    @pool = null
    document.on 'viewer:searched-tags-changed', (e) =>
      @searched_tags = e.memo.tags ? ''
      @update()

    document.on 'viewer:displayed-post-changed', (e) =>
      @post_id = e.memo.post_id
      @post_frame = e.memo.post_id
      @update()

    document.on 'viewer:displayed-pool-changed', (e) =>
      @pool = e.memo.pool
      @update()

    @update()


  update: =>
    if @pool
      post = Post.posts.get(@post_id)
      title = @pool.name.replace(/_/g, ' ')

      if post?.pool_posts
        pool_post = post.pool_posts[@pool.id]
        if pool_post
          sequence = pool_post.sequence
          title += ' '
          if sequence.match(/^[0-9]/)
            title += '#'
          title += sequence
    else
      title = "/#{@searched_tags.replace(/_/g, ' ')}"

    title += ' - Browse'
    document.title = title


class Navigator
  constructor: (container, target) ->
    @container = container
    @target = target
    @hovering = false
    @autohide = false
    @img = @container.down('.image-navigator-img')
    @container.show()
    @handlers = []
    @handlers.push @container.on('mousedown', @mousedown_event)
    @handlers.push @container.on('mouseover', @mouseover_event)
    @handlers.push @container.on('mouseout', @mouseout_event)
    @dragger = new DragElement(@container, snap_pixels: 0, onenddrag: @enddrag, ondrag: @ondrag)


  set_image: (image_url, width, height) ->
    @img.src = image_url
    @img.width = width
    @img.height = height


  enable: (enabled) ->
    @container.show enabled


  mouseover_event: (e) =>
    return if e.relatedTarget?.isParentNode(@container)

    debug "over #{e.target.className}, #{@container.className}, #{e.target.isParentNode(@container)}"
    @hovering = true
    @update_visibility()


  mouseout_event: (e) =>
    return if e.relatedTarget?.isParentNode(@container)

    debug "out #{e.target.className}"
    @hovering = false
    @update_visibility()


  mousedown_event: (e) =>
    x = e.pointerX()
    y = e.pointerY()
    coords = @get_normalized_coords(x, y)
    @center_on_position coords


  enddrag: (e) =>
    @shift_lock_anchor = null
    @locked_to_x = null
    @update_visibility()


  ondrag: (e) =>
    coords = @get_normalized_coords(e.x, e.y)
    if e.latest_event.shiftKey != @shift_lock_anchor?

      # The shift key has been pressed or released.
      if e.latest_event.shiftKey
        # The shift key was just pressed.  Remember the position we were at when it was
        # pressed.
        @shift_lock_anchor = [
          coords[0]
          coords[1]
        ]
      else
        # The shift key was released.
        @shift_lock_anchor = null
        @locked_to_x = null
    @center_on_position coords


  image_position_changed: (percent_x, percent_y, height_percent, width_percent) ->

    # When the image is moved or the visible area is resized, update the cursor rectangle.
    cursor = @container.down('.navigator-cursor')
    cursor.setStyle
      top: @img.height * (percent_y - (height_percent / 2)) + 'px'
      left: @img.width * (percent_x - (width_percent / 2)) + 'px'
      width: @img.width * width_percent + 'px'
      height: @img.height * height_percent + 'px'


  get_normalized_coords: (x, y) ->
    offset = @img.cumulativeOffset()
    x -= offset.left
    y -= offset.top
    x /= @img.width
    y /= @img.height

    [x, y]


  # x and y are absolute window coordinates.
  center_on_position: (coords) ->
    if @shift_lock_anchor
      if !@locked_to_x?

        # Only change the coordinate with the greater delta.
        change_x = Math.abs(coords[0] - (@shift_lock_anchor[0]))
        change_y = Math.abs(coords[1] - (@shift_lock_anchor[1]))

        # Only lock to moving vertically or horizontally after we've moved a small distance
        # from where shift was pressed.
        if change_x > 0.1 || change_y > 0.1
          @locked_to_x = change_x > change_y

      # If we've chosen an axis to lock to, apply it.
      if @locked_to_x?
        if @locked_to_x
          coords[1] = @shift_lock_anchor[1]
        else
          coords[0] = @shift_lock_anchor[0]
    coords[0] = Math.max(0, Math.min(coords[0], 1))
    coords[1] = Math.max(0, Math.min(coords[1], 1))
    @target.fire 'viewer:center-on',
      x: coords[0]
      y: coords[1]


  set_autohide: (autohide) ->
    @autohide = autohide
    @update_visibility()


  update_visibility: ->
    box = @container.down('.image-navigator-box')
    visible = !@autohide || @hovering || @dragger.dragging
    box.style.visibility = if visible then 'visible' else 'hidden'


  destroy: ->
    @dragger.destroy()
    @handlers.each (h) -> h.stop()
    @dragger = @handlers = null
    @container.hide()
