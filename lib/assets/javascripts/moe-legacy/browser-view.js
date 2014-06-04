/*
 * We have a few competing goals:
 *
 * First, be as responsive as possible.  Preload nearby post HTML and their images.
 *
 * If data in a post page changes, eg. if the user votes, then coming back to the page
 * later should retain the changes.  This means either requesting the page again, or
 * retaining the document node and reusing it, so we preserve the changes that were
 * made in-place.
 *
 * Don't use too much memory.  If we keep every document node in memory as we use it,
 * the images will probably be kept around too.  Release older nodes, so the browser
 * is more likely to release images that havn't been used in a while.
 *
 * We do the following:
 * - When we load a new post, it's formatted and its scripts are evaluated normally.
 * - When we're replacing the displayed post, its node is stashed away in a node cache.
 * - If we come back to the post while it's in the node cache, we'll use the node directly.
 * - HTML and images for posts are preloaded.  We don't use a simple mechanism like
 *   Preload.preload_raw, because Opera's caching is broken for XHR and it'll always
 *   do a slow revalidation.
 * - We don't depend on browser caching for HTML.  That would require us to expire a
 *   page when we switch away from it if we've made any changes (eg. voting), so we
 *   don't pull an out-of-date page next time.  This is slower, and would require us
 *   to be careful about expiring the cache.
 */

BrowserView = function(container)
{
  this.container = container;

  /* The post that we currently want to display.  This will be either one of the
   * current html_preloads, or be the displayed_post_id. */
  this.wanted_post_id = null;
  this.wanted_post_frame = null;

  /* The post that's currently actually being displayed. */
  this.displayed_post_id = null;
  this.displayed_post_frame = null;

  this.current_ajax_request = null;
  this.last_preload_request = [];
  this.last_preload_request_active = false;

  this.image_pool = new ImgPoolHandler();
  this.img_box = this.container.down(".image-box");
  this.container.down(".image-canvas");

  /* In Opera 10.63, the img.complete property is not reset to false after changing the
   * src property.  Blits from images to the canvas silently fail, with nothing being
   * blitted and no exception raised.  This causes blank canvases to be displayed, because
   * we have no way of telling whether the image is blittable or if the blit succeeded. */
  if(!Prototype.Browser.Opera)
    this.canvas = create_canvas_2d();
  if(this.canvas)
  {
    this.canvas.hide();
    this.img_box.appendChild(this.canvas);
  }
  this.zoom_level = 0;

  /* True if the post UI is visible. */
  this.post_ui_visible = true;

  this.update_navigator = this.update_navigator.bind(this);

  Event.on(window, "resize", this.window_resize_event.bindAsEventListener(this));
  document.on("viewer:vote", function(event) { if(this.vote_widget) this.vote_widget.set(event.memo.score); }.bindAsEventListener(this));

  if(TagCompletion)
    TagCompletion.init();

  /* Double-clicking the main image, or on nothing, toggles the thumb bar. */
  this.container.down(".image-container").on("dblclick", ".image-container", function(event) {
    /* Watch out: Firefox fires dblclick events for all buttons, with the standard
     * button maps, but IE only fires it for left click and doesn't set button at
     * all, so event.isLeftClick won't work. */
    if(event.button)
      return;

    event.stop();
    document.fire("viewer:set-thumb-bar", {toggle: true});
  }.bindAsEventListener(this));

  /* Image controls: */
  document.on("viewer:view-large-toggle", function(e) { this.toggle_view_large_image(); }.bindAsEventListener(this));
  this.container.down(".post-info").on("click", ".toggle-zoom", function(e) { e.stop(); this.toggle_view_large_image(); }.bindAsEventListener(this));
  this.container.down(".parent-post").down("A").on("click", this.parent_post_click_event.bindAsEventListener(this));
  this.container.down(".child-posts").down("A").on("click", this.child_posts_click_event.bindAsEventListener(this));

  this.container.down(".post-frames").on("click", ".post-frame-link", function(e, item) {
    e.stop();

    /* Change the displayed post frame to the one that was clicked.  Since all post frames
     * are usually displayed in the thumbnail view, set center_thumbs to true to recenter
     * on the thumb that was clicked, so it's clearer what's happening. */
    document.fire("viewer:set-active-post", {post_id: this.displayed_post_id, post_frame: item.post_frame, center_thumbs: true});
  }.bind(this));

  /* We'll receive this message from the thumbnail view when the overlay is
   * visible on the bottom of the screen, to tell us how much space is covered up
   * by it. */
  this.thumb_bar_height = 0;
  document.on("viewer:thumb-bar-changed", function(e) {
    /* Update the thumb bar height and rescale the image to fit the new area. */
    this.thumb_bar_height = e.memo.height;
    this.update_image_window_size();

    this.set_post_ui(e.memo.shown);
    this.scale_and_position_image(true);
  }.bindAsEventListener(this));

/*
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
*/
  /* Hide member-only and moderator-only controls: */
  $(document.body).pickClassName("is-member", "not-member", User.is_member_or_higher());
  $(document.body).pickClassName("is-moderator", "not-moderator", User.is_mod_or_higher());

  var tag_span = this.container.down(".post-tags");
  tag_span.on("click", ".post-tag", function(e, element) {
    e.stop();
    document.fire("viewer:perform-search", {tags: element.tag_name});
  }.bind(this));

  /* These two links do the same thing, but one is shown to approve a pending post
   * and the other is shown to unflag a flagged post, so they prompt differently. */
  this.container.down(".post-approve").on("click", function(e) {
    e.stop();
    if(!confirm("Approve this post?"))
      return;
    var post_id = this.displayed_post_id;
    Post.approve(post_id, false);
  }.bindAsEventListener(this));

  this.container.down(".post-unflag").on("click", function(e) {
    e.stop();
    if(!confirm("Unflag this post?"))
      return;
    var post_id = this.displayed_post_id;
    Post.unflag(post_id);
  }.bindAsEventListener(this));

  this.container.down(".post-delete").on("click", function(e) {
    e.stop();
    var post = Post.posts.get(this.displayed_post_id);
    var default_reason = "";
    if(post.flag_detail)
      default_reason = post.flag_detail.reason;

    var reason = prompt("Reason:", default_reason);
    if(!reason || reason == "")
      return;
    var post_id = this.displayed_post_id;
    Post.approve(post_id, reason);
  }.bindAsEventListener(this));

  this.container.down(".post-undelete").on("click", function(e) {
    e.stop();
    if(!confirm("Undelete this post?"))
      return;
    var post_id = this.displayed_post_id;
    Post.undelete(post_id);
  }.bindAsEventListener(this));

  this.container.down(".flag-button").on("click", function(e) {
    e.stop();
    var post_id = this.displayed_post_id;
    Post.flag(post_id);
  }.bindAsEventListener(this));

  this.container.down(".activate-post").on("click", function(e) {
    e.stop();

    var post_id = this.displayed_post_id;
    if(!confirm("Activate this post?"))
      return;
    Post.update_batch([{ id: post_id, is_held: false }], function()
    {
      var post = Post.posts.get(post_id);
      if(post.is_held)
        notice("Couldn't activate post");
      else
        notice("Activated post");
    }.bind(this));
  }.bindAsEventListener(this));

  this.container.down(".reparent-post").on("click", function(e) {
    e.stop();

    if(!confirm("Make this post the parent?"))
      return;

    var post_id = this.displayed_post_id;
    var post = Post.posts.get(post_id);
    if(post == null)
      return;

    Post.reparent_post(post_id, post.parent_id, false);
  }.bindAsEventListener(this));

  this.container.down(".pool-info").on("click", ".remove-pool-from-post", function(e, element)
  {
    e.stop();
    var pool_info = element.up(".pool-info");
    var pool = Pool.pools.get(pool_info.pool_id);
    var pool_name = pool.name.replace(/_/g, ' ');
    if(!confirm("Remove this post from pool #" + pool_info.pool_id + ": " + pool_name + "?"))
      return;

    Pool.remove_post(pool_info.post_id, pool_info.pool_id);
  }.bind(this));

  /* Post editing: */
  var post_edit = this.container.down(".post-edit");
  post_edit.down("FORM").on("submit", function(e) { e.stop(); this.edit_save(); }.bindAsEventListener(this));
  this.container.down(".show-tag-edit").on("click", function(e) { e.stop(); this.edit_show(true); }.bindAsEventListener(this));
  this.container.down(".edit-save").on("click", function(e) { e.stop(); this.edit_save(); }.bindAsEventListener(this));
  this.container.down(".edit-cancel").on("click", function(e) { e.stop(); this.edit_show(false); }.bindAsEventListener(this));

  this.edit_post_area_changed = this.edit_post_area_changed.bind(this);
  post_edit.down(".edit-tags").on("paste", function(e) { this.edit_post_area_changed.defer(); }.bindAsEventListener(this));
  post_edit.down(".edit-tags").on("keydown", function(e) { this.edit_post_area_changed.defer(); }.bindAsEventListener(this));
  new TagCompletionBox(post_edit.down(".edit-tags"));

  this.container.down(".post-edit").on("keydown", function(e) {
    /* Don't e.stop() KEY_ESC, so we fall through and let handle_keypress unfocus the
     * form entry, if any.  Otherwise, Chrome gets confused and leaves the focus on the
     * hidden input, where it'll steal keystrokes. */
    if (e.keyCode == Event.KEY_ESC) { this.edit_show(false); }
    else if (e.keyCode == Event.KEY_RETURN) { e.stop(); this.edit_save(); }
  }.bindAsEventListener(this));

  /* When the edit-post hotkey is pressed (E), force the post UI open and show editing. */
  document.on("viewer:edit-post", function(e) {
    document.fire("viewer:set-thumb-bar", { set: true });
    this.edit_show(true);
  }.bindAsEventListener(this));

  /* When the post that's currently being displayed is updated by an API call, update
   * the displayed info. */
  document.on("posts:update", function(e) {
    if(e.memo.post_ids.get(this.displayed_post_id) == null)
      return;
    this.set_post_info();
  }.bindAsEventListener(this));

  this.vote_widget = new Vote(jQuery(this.container.down(".vote-container"), null));
  this.vote_widget.initShortcut();

  this.blacklist_override_post_id = null;
  this.container.down(".show-blacklisted").on("click", function(e) { e.preventDefault(); }.bindAsEventListener(this));
  this.container.down(".show-blacklisted").on("dblclick", function(e) {
    e.stop();
    this.blacklist_override_post_id = this.displayed_post_id;
    var post = Post.posts.get(this.displayed_post_id);
    this.set_main_image(post, this.displayed_post_frame);
  }.bindAsEventListener(this));


  this.img_box.on("viewer:center-on", function(e) { this.center_image_on(e.memo.x, e.memo.y); }.bindAsEventListener(this));

  this.navigator = new Navigator(this.container.down(".image-navigator"), this.img_box);

  this.container.on("swipe:horizontal", function(e) { document.fire("viewer:show-next-post", { prev: e.memo.right }); }.bindAsEventListener(this));

  if(Prototype.BrowserFeatures.Touchscreen)
  {
    this.create_voting_popup();
    this.image_swipe = new SwipeHandler(this.container.down(".image-container"));
  }

  /* Create the frame editor.  This must be created before image_dragger, since it takes priority
   * for drags. */
  this.container.down(".edit-frames-button").on("click", function(e) { e.stop(); this.show_frame_editor(); }.bindAsEventListener(this));
  this.frame_editor = new FrameEditor(this.container.down(".frame-editor"), this.img_box, this.container.down(".frame-editor-popup"),
  {
    onClose: function() {
      this.hide_frame_editor();
    }.bind(this)
  });

  /* If we're using dragging as a swipe gesture (see SwipeHandler), don't use it for
   * dragging too. */
  if(this.image_swipe == null)
    this.image_dragger = new WindowDragElementAbsolute(this.img_box, this.update_navigator);
}

BrowserView.prototype.create_voting_popup = function()
{
  /* Create the low-level voting widget. */
  var popup_vote_widget_container = this.container.down(".vote-popup-container");
  popup_vote_widget_container.show();
  this.popup_vote_widget = new Vote(jQuery(popup_vote_widget_container), null);
  this.popup_vote_widget.initShortcut();

  var flash = this.container.down(".vote-popup-flash");

  /* vote-popup-expand is the part that's always present and is clicked to display the
   * voting popup.  Create a dragger on it, and pass the position down to the voting
   * popup as we drag around. */
  var popup_expand = this.container.down(".vote-popup-expand");
  popup_expand.show();

  var last_dragged_over = null;

  this.popup_vote_dragger = new DragElement(popup_expand, {
    ondown: function(drag) {
      /* Stop the touchdown/mousedown events, so this drag takes priority over any
       * others.  In particular, we don't want this.image_swipe to also catch this
       * as a drag. */
      drag.latest_event.stop();

      flash.hide();
      flash.removeClassName("flash-star");

      this.popup_vote_widget.set_mouseover(null);
      last_dragged_over = null;
      popup_vote_widget_container.removeClassName("vote-popup-hidden");
    }.bind(this),

    onup: function(drag) {
      /* If we're cancelling the drag, don't activate the vote, if any. */
      if(drag.cancelling)
      {
        debug("cancelling drag");
        last_dragged_over = null;
      }

      /* Call even if star_container is null or not a star, so we clear any mouseover. */
      this.popup_vote_widget.set_mouseover(last_dragged_over);

      var star = this.popup_vote_widget.activate_item(last_dragged_over);

      /* If a vote was made, flash the vote star. */
      if(star != null)
      {
        /* Set the star-# class to color the star. */
        for(var i = 0; i < 4; ++i)
          flash.removeClassName("star-" + i);
        flash.addClassName("star-" + star);

        flash.show();

        /* Center the element on the screen. */
        var offset = this.image_window_size;
        var flash_x = offset.width/2 - flash.offsetWidth/2;
        var flash_y = offset.height/2 - flash.offsetHeight/2;
        flash.setStyle({left: flash_x + "px", top: flash_y + "px"});
        flash.addClassName("flash-star");
      }

      popup_vote_widget_container.addClassName("vote-popup-hidden");
      last_dragged_over = null;
    }.bind(this),

    ondrag: function(drag) {
      last_dragged_over = document.elementFromPoint(drag.x, drag.y);
      this.popup_vote_widget.set_mouseover(last_dragged_over);
    }.bind(this)
  });
}


BrowserView.prototype.set_post_ui = function(visible)
{
  /* Disable the post UI by default on touchscreens; we don't have an interface
   * to toggle it. */
  if(Prototype.BrowserFeatures.Touchscreen && window.screen.availWidth < 1024)
    visible = false;

  /* If we don't have a post displayed, always hide the post UI even if it's currently
   * shown. */
  this.container.down(".post-info").show(visible && this.displayed_post_id != null);

  if(visible == this.post_ui_visible)
    return;

  this.post_ui_visible = visible;
  if(this.navigator)
    this.navigator.set_autohide(!visible);

  /* If we're hiding the post UI, cancel the post editor if it's open. */
  if(!this.post_ui_visible)
    this.edit_show(false);
}


BrowserView.prototype.image_loaded_event = function(event)
{
  /* Record that the image is completely available, so it can be blitted to the canvas.
   * This is different than img.complete, which is true if the image has completed downloading
   * but hasn't yet been decoded, so isn't yet completely available.  This generally happens
   * if we query img.completed quickly after setting img.src and the image data is cached. */
  this.img.fully_loaded = true;

  document.fire("viewer:displayed-image-loaded", { post_id: this.displayed_post_id, post_frame: this.displayed_post_frame });
  this.update_canvas();
}

/* Return true if last_preload_request includes [post_id, post_frame]. */
BrowserView.prototype.post_frame_list_includes = function(post_id_list, post_id, post_frame)
{
  var found_preload = post_id_list.find(function(post) { return post[0] == post_id && post[1] == post_frame; });
  return found_preload != null;
}

/* Begin preloading the HTML and images for the given post IDs. */
BrowserView.prototype.preload = function(post_ids)
{
  /* We're being asked to preload post_ids.  Only do this if it seems to make sense: if
   * the user is actually traversing posts that are being preloaded.  Look at the previous
   * call to preload().  If it didn't include the current post, then skip the preload. */
  var last_preload_request = this.last_preload_request;
  this.last_preload_request = post_ids;

  if(!this.post_frame_list_includes(last_preload_request, this.wanted_post_id, this.wanted_post_frame))
  {
    // debug("skipped-preload(" + post_ids.join(",") + ")");
    this.last_preload_request_active = false;
    return;
  }
  this.last_preload_request_active = true;
  // debug("preload(" + post_ids.join(",") + ")");

  var new_preload_container = new PreloadContainer();
  for(var i = 0; i < post_ids.length; ++i)
  {
    var post_id = post_ids[i][0];
    var post_frame = post_ids[i][1];
    var post = Post.posts.get(post_id);

    if(post_frame != -1)
    {
      var frame = post.frames[post_frame];
      new_preload_container.preload(frame.url);
    }
    else
      new_preload_container.preload(post.sample_url);
  }

  /* If we already were preloading images, we created the new preloads before
   * deleting the old ones.  That way, any images that are still being preloaded
   * won't be deleted and recreated, possibly causing the download to be interrupted
   * and resumed. */
  if(this.preload_container)
    this.preload_container.destroy();
  this.preload_container = new_preload_container;
}

BrowserView.prototype.load_post_id_data = function(post_id)
{
  debug("load needed");

  // If we already have a request in flight, don't start another; wait for the
  // first to finish.
  if(this.current_ajax_request != null)
    return;

  new Ajax.Request("/post.json", {
    parameters: {
      tags: "id:" + post_id,
      api_version: 2,
      filter: 1,
      include_tags: "1",
      include_votes: "1",
      include_pools: 1
    },
    method: "get",

    onCreate: function(resp) {
      this.current_ajax_request = resp.request;
    }.bind(this),

    onSuccess: function(resp) {
      if(this.current_ajax_request != resp.request)
        return;

      /* If no posts were returned, then the post ID we're looking up doesn't exist;
       * treat this as a failure. */
      var resp = resp.responseJSON;
      this.success = resp.posts.length > 0;
      if(!this.success)
      {
        notice("Post #" + post_id + " doesn't exist");
        return;
      }

      Post.register_resp(resp);
    }.bind(this),

    onComplete: function(resp) {
      if(this.current_ajax_request == resp.request)
        this.current_ajax_request = null;

      /* If the request failed and we were requesting wanted_post_id, don't keep trying. */
      var success = resp.request.success() && this.success;
      if(!success && post_id == this.wanted_post_id)
      {
        /* As a special case, if the post we requested doesn't exist and we aren't displaying
         * anything at all, force the thumb bar open so we don't show nothing at all. */
        if(this.displayed_post_id == null)
          document.fire("viewer:set-thumb-bar", {set: true});

        return;
      }

      /* This will either load the post we just finished, or request data for the
       * one we want. */
      this.set_post(this.wanted_post_id, this.wanted_post_frame);
    }.bind(this),

    onFailure: function(resp) {
      notice("Error " + resp.status + " loading post");
    }.bind(this)
  });
}

BrowserView.prototype.set_viewing_larger_version = function(b)
{
  this.viewing_larger_version = b;

  var post = Post.posts.get(this.displayed_post_id);
  var can_zoom = post != null && post.jpeg_url != post.sample_url;
  this.container.down(".zoom-icon-none").show(!can_zoom);
  this.container.down(".zoom-icon-in").show(can_zoom && !this.viewing_larger_version);
  this.container.down(".zoom-icon-out").show(can_zoom && this.viewing_larger_version);

  /* When we're on the regular version and we're on a touchscreen, disable drag
   * scrolling so we can use it to switch images instead. */
  if(Prototype.BrowserFeatures.Touchscreen && this.image_dragger)
    this.image_dragger.set_disabled(!b);

  /* Only allow dragging to create new frames when not viewing the large version,
   * since we need to be able to drag the image. */
  if(this.frame_editor)
  {
    this.frame_editor.set_drag_to_create(!b);
    this.frame_editor.set_show_corner_drag(!b);
  }
}

BrowserView.prototype.set_main_image = function(post, post_frame)
{
  /*
   * Clear the previous post, if any.  Don't keep the old IMG around; create a new one, or
   * we may trigger long-standing memory leaks in WebKit, eg.:
   * https://bugs.webkit.org/show_bug.cgi?id=31253
   *
   * This also helps us avoid briefly displaying the old image with the new dimensions, which
   * can otherwise take some hoop jumping to prevent.
   */
  if(this.img != null)
  {
    this.img.stopObserving();
    this.img.parentNode.removeChild(this.img);
    this.image_pool.release(this.img);
    this.img = null;
  }

  /* If this post is blacklisted, show a message instead of displaying it. */
  var hide_post = Post.is_blacklisted(post.id) && post.id != this.blacklist_override_post_id;
  this.container.down(".blacklisted-message").show(hide_post);
  if(hide_post)
    return;

  this.img = this.image_pool.get();
  this.img.className = "main-image";

  if(this.canvas)
    this.canvas.hide();
  this.img.show();

  /*
   * Work around an iPhone bug.  If a touchstart event is sent to this.img, and then
   * (due to a swipe gesture) we remove the image and replace it with a new one, no
   * touchend is ever delivered, even though it's the containing box listening to the
   * event.  Work around this by setting the image to pointer-events: none, so clicks on
   * the image will actually be sent to the containing box directly.
   */
  this.img.setStyle({pointerEvents: "none"});

  this.img.on("load", this.image_loaded_event.bindAsEventListener(this));

  this.img.fully_loaded = false;
  if(post_frame != -1 && post_frame < post.frames.length)
  {
    var frame = post.frames[post_frame];
    this.img.src = frame.url;
    this.img_box.original_width = frame.width;
    this.img_box.original_height = frame.height;
    this.img_box.show();
  }
  else if(this.viewing_larger_version && post.jpeg_url)
  {
    this.img.src = post.jpeg_url;
    this.img_box.original_width = post.jpeg_width;
    this.img_box.original_height = post.jpeg_height;
    this.img_box.show();
  }
  else if(!this.viewing_larger_version && post.sample_url)
  {
    this.img.src = post.sample_url;
    this.img_box.original_width = post.sample_width;
    this.img_box.original_height = post.sample_height;
    this.img_box.show();
  }
  else
  {
    /* Having no sample URL is an edge case, usually from deleted posts.  Keep the number
     * of code paths smaller by creating the IMG anyway, but not showing it. */
    this.img_box.hide();
  }

  this.container.down(".image-box").appendChild(this.img);

  if(this.viewing_larger_version)
  {
    this.navigator.set_image(post.preview_url, post.actual_preview_width, post.actual_preview_height);
    this.navigator.set_autohide(!this.post_ui_visible);
  }
  this.navigator.enable(this.viewing_larger_version);

  this.scale_and_position_image();
}

/*
 * Display post_id.  If post_frame is not null, set the specified frame.
 *
 * If no_hash_change is true, the UrlHash will not be updated to reflect the new post.
 * This should be used when this is called to load the post already reflected by the
 * URL hash.  For example, the hash "#/pool:123" shows pool 123 in the thumbnails and
 * shows its first post in the view.  It should *not* change the URL hash to reflect
 * the actual first post (eg. #12345/pool:123).  This will insert an unwanted history
 * state in the browser, so the user has to go back twice to get out.
 *
 * no_hash_change should also be set when loading a state as a result of hashchange,
 * for similar reasons.
 */
BrowserView.prototype.set_post = function(post_id, post_frame, lazy, no_hash_change, replace_history)
{
  if(post_id == null)
    throw "post_id must not be null";

  /* If there was a lazy load pending, cancel it. */
  this.cancel_lazily_load();

  this.wanted_post_id = post_id;
  this.wanted_post_frame = post_frame;
  this.wanted_post_no_hash_change = no_hash_change;
  this.wanted_post_replace_history = replace_history;

  if(post_id == this.displayed_post_id && post_frame == this.displayed_post_frame)
    return;

  /* If a lazy load was requested and we're not yet loading the image for this post,
   * delay loading. */
  var is_cached = this.last_preload_request_active && this.post_frame_list_includes(this.last_preload_request, post_id, post_frame);
  if(lazy && !is_cached)
  {
    this.lazy_load_timer = window.setTimeout(function() {
      this.lazy_load_timer = null;
      this.set_post(this.wanted_post_id, this.wanted_post_frame, false, this.wanted_post_no_hash_change, this.wanted_post_replace_history);
    }.bind(this), 500);
    return;
  }

  this.hide_frame_editor();

  var post = Post.posts.get(post_id);
  if(post == null)
  {
    /* The post we've been asked to display isn't loaded.  Request a load and come back. */
    if(this.displayed_post_id == null)
      this.container.down(".post-info").hide();

    this.load_post_id_data(post_id);
    return;
  }

  if(post_frame == null) {
    // If post_frame is unspecified and we have a frame, display the first.
    post_frame = this.get_default_post_frame(post_id);

    // We know what frame we actually want to display now, so update wanted_post_frame.
    this.wanted_post_frame = post_frame;
  }

  /* If post_frame doesn't exist, just display the main post. */
  if(post_frame != -1 && post.frames.length <= post_frame)
    post_frame = -1;

  this.displayed_post_id = post_id;
  this.displayed_post_frame = post_frame;
  if(!no_hash_change) {
    var post_frame_hash = this.get_post_frame_hash(post, post_frame);
    UrlHash.set_deferred({"post-id": post_id, "post-frame": post_frame_hash}, replace_history);
  }

  this.set_viewing_larger_version(false);

  this.set_main_image(post, post_frame);

  if(this.vote_widget) {
    if (this.vote_widget.post_id) {
      Post.votes.set(this.vote_widget.post_id, this.vote_widget.data.vote);
      Post.posts.get(this.vote_widget.post_id).score = this.vote_widget.data.score;
    }
    this.vote_widget.post_id = post.id;
    this.vote_widget.updateWidget(Post.votes.get(post.id), post.score);
  };
  if(this.popup_vote_widget) {
    this.popup_vote_widget.post_id = post.id;
    this.popup_vote_widget.updateWidget(Post.votes.get(post.id), post.score);
  };

  document.fire("viewer:displayed-post-changed", { post_id: post_id, post_frame: post_frame });

  this.set_post_info();

  /* Hide the editor when changing posts. */
  this.edit_show(false);
}

/* Return the frame spec for the hash, eg. "-0".
 *
 * If the post has no frames, then just omit the frame spec.  If the post has any frames,
 * then return the frame number or "-F" for the full image. */
BrowserView.prototype.post_frame_hash = function(post, post_frame)
{
  if(post.frames.length == 0)
    return "";
  return "-" + (post_frame == -1? "F":post_frame);
}

/* Return the default frame to display for the given post.  If the post isn't loaded,
 * we don't know which frame we'll display and null will be returned.  This corresponds
 * to a hash of #1234, where no frame is specified (eg. #1234-F, #1234-0). */
BrowserView.prototype.get_default_post_frame = function(post_id)
{
  var post = Post.posts.get(post_id);
  if(post == null)
    return null;

  return post.frames.length > 0? 0: -1;
}

BrowserView.prototype.get_post_frame_hash = function(post, post_frame)
{
/*
 * Omitting the frame in the hash selects the default frame: the first frame if any,
 * otherwise the full image.  If we're setting the hash to a post_frame which would be
 * selected by this default, omit the frame so this default is used.  For example, if
 * post #1234 has one frame and post_frame is 0, it would be selected by the default,
 * so omit the frame and use a hash of #1234, not #1234-0.
 *
 * This helps normalize the hash.  Otherwise, loading /#1234 will update the hash to
 * /#1234-in set_post, causing an unwanted history entry.
 */
  var default_frame = post.frames.length > 0? 0:-1;
  if(post_frame == default_frame)
    return null;
  else
    return post_frame;
}
/* Set the post info box for the currently displayed post. */
BrowserView.prototype.set_post_info = function()
{
  var post = Post.posts.get(this.displayed_post_id);
  if(!post)
    return;

  this.container.down(".post-id").setTextContent(post.id);
  this.container.down(".post-id-link").href = "/post/show/" + post.id;
  this.container.down(".posted-by").show();
  this.container.down(".posted-at").setTextContent(time_ago_in_words(new Date(post.created_at*1000)));

  /* Fill in the pool list. */
  var pool_info = this.container.down(".pool-info");
  while(pool_info.firstChild)
    pool_info.removeChild(pool_info.firstChild);
  if(post.pool_posts)
  {
    post.pool_posts.each(function(pp) {
      var pool_post = pp[1];
      var pool_id = pool_post.pool_id;
      var pool = Pool.pools.get(pool_id);

      var pool_title = pool.name.replace(/_/g, " ");
      var sequence = pool_post.sequence;
      if(sequence.match(/^[0-9]/))
        sequence = "#" + sequence;

      var html =
        '<div class="pool-info">Post ${sequence} in <a class="pool-link" href="/post/browse#/pool:${pool_id}">${desc}</a> ' +
        '(<a target="_blank" href="/pool/show/${pool_id}">pool page</a>)';

      if(Pool.can_edit_pool(pool))
        html += '<span class="advanced-editing"> (<a href="#" class="remove-pool-from-post">remove</a>)</div></span>';

      var div = html.subst({
        sequence: sequence,
        pool_id: pool_id,
        desc: pool_title.escapeHTML()
      }).createElement();

      div.post_id = post.id;
      div.pool_id = pool_id;

      pool_info.appendChild(div);
    }.bind(this));
  }

  if(post.creator_id != null)
  {
    this.container.down(".posted-by").down("A").href = "/user/show/" + post.creator_id;
    this.container.down(".posted-by").down("A").setTextContent(post.author);
  } else {
    this.container.down(".posted-by").down("A").href = "#"
    this.container.down(".posted-by").down("A").setTextContent('Anonymous');
  }

  this.container.down(".post-dimensions").setTextContent(post.width + "x" + post.height);
  this.container.down(".post-source").show(post.source != "");
  if(post.source != "")
  {
    var text = post.source;
    var url = null;

    var m = post.source.match(/^http:\/\/.*pixiv\.net\/(img\d+\/)?img\/(\w+)\/(\d+)(_.+)?\.\w+$/);
    if(m)
    {
      text = "pixiv #" + m[3] + " (" + m[2] + ")";
      url = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=" + m[3];
    }
    else if(post.source.substr(0, 7) == "http://")
    {
      text = text.substr(7);
      if(text.substr(0, 4) == "www.")
        text = text.substr(4);
      if(text.length > 20)
        text = text.substr(0, 20) + "...";
      url = post.source;
    }

    var source_box = this.container.down(".post-source");

    source_box.down("A").show(url != null);
    source_box.down("SPAN").show(url == null);
    if(url)
    {
      source_box.down("A").href = url;
      source_box.down("A").setTextContent(text);
    }
    else
    {
      source_box.down("SPAN").setTextContent(text);
    }

  }

  if(post.frames.length > 0)
  {
    /* Hide this with a class rather than by changing display, so show_frame_editor
     * and hide_frame_editor can hide and unhide this separately. */
    this.container.down(".post-frames").removeClassName("no-frames");

    var frame_list = this.container.down(".post-frame-list");
    while(frame_list.firstChild)
      frame_list.removeChild(frame_list.firstChild);

    for(var i = -1; i < post.frames.length; ++i)
    {
      var text = i == -1? "main": (i+1);

      var a = document.createElement("a");
      a.href = "/post/browse#" + post.id  + this.post_frame_hash(post, i);

      a.className = "post-frame-link";
      if(this.displayed_post_frame == i)
        a.className += " current-post-frame";

      a.setTextContent(text);
      a.post_frame = i;
      frame_list.appendChild(a);
    }
  }
  else
  {
    this.container.down(".post-frames").addClassName("no-frames");
  }


  var ratings = {s: "Safe", q: "Questionable", e: "Explicit"};
  this.container.down(".post-rating").setTextContent(ratings[post.rating]);
  this.container.down(".post-score").setTextContent(post.score);
  this.container.down(".post-hidden").show(!post.is_shown_in_index);

  this.container.down(".post-info").show(this.post_ui_visible);

  var file_extension = function(path)
  {
    var m = path.match(/.*\.([^.]+)/);
    if(!m)
      return "";
    return m[1];
  }

  var has_sample = (post.sample_url != post.file_url);
  var has_jpeg = (post.jpeg_url != post.file_url);
  var has_image = post.file_url != null && !has_sample;

  /* Hide the whole download-links box if there are no downloads available, usually
   * because of a deleted post. */
  this.container.down(".download-links").show(has_image || has_sample || has_jpeg);

  this.container.down(".download-image").show(has_image);
  if(has_image)
  {
    this.container.down(".download-image").href = post.file_url;
    this.container.down(".download-image-desc").setTextContent(number_to_human_size(post.file_size) + " " + file_extension(post.file_url.toUpperCase()));
  }

  this.container.down(".download-jpeg").show(has_sample);
  if(has_sample)
  {
    this.container.down(".download-jpeg").href = has_jpeg? post.jpeg_url: post.file_url;
    var image_desc = number_to_human_size(has_jpeg? post.jpeg_file_size: post.file_size) /*+ " " + post.jpeg_width + "x" + post.jpeg_height*/ + " JPG";
    this.container.down(".download-jpeg-desc").setTextContent(image_desc);
  }

  this.container.down(".download-png").show(has_jpeg);
  if(has_jpeg)
  {
    this.container.down(".download-png").href = post.file_url;
    var png_desc = number_to_human_size(post.file_size) /*+ " " + post.width + "x" + post.height*/ + " " + file_extension(post.file_url.toUpperCase());
    this.container.down(".download-png-desc").setTextContent(png_desc);
  }

  /* For links that are handled by click events, try to set the href so that copying the
   * link will give a similar effect.  For example, clicking parent-post will call set_post
   * to display it, and the href links to /post/browse#12345. */
  var parent_post = this.container.down(".parent-post");
  parent_post.show(post.parent_id != null);
  if(post.parent_id)
    parent_post.down("A").href = "/post/browse#" + post.parent_id;

  var child_posts = this.container.down(".child-posts");
  child_posts.show(post.has_children);
  if(post.has_children)
    child_posts.down("A").href = "/post/browse#/parent:" + post.id;


  /* Create the tag links. */
  var tag_span = this.container.down(".post-tags");
  var first = true;
  while(tag_span.firstChild)
    tag_span.removeChild(tag_span.firstChild);


  var tags_by_type = Post.get_post_tags_with_type(post);
  tags_by_type.each(function(t) {
      var tag = t[0];
      var type = t[1];

      var span = $(document.createElement("SPAN", ""));
      span = $(span);
      span.className = "tag-type-" + type;

      var space = document.createTextNode(" ");
      span.appendChild(space);

      var a =
        jQuery('<a>', {
          text: tag,
          href: "/post/browse#/" + tag,
          class: "post-tag tag-type-" + type,
        });
      /* Break tags with <wbr>, so long tags can be wrapped. */
      a.html(a.html().replace(/_/g, '_<wbr>'));
      /* convert back to something Prototype or whatever can understand */
      a = a[0];
      a.tag_name = tag;
      span.appendChild(a);
      tag_span.appendChild(span);
  });

  var flag_post = this.container.down(".flag-button");
  flag_post.show(post.status == "active");

  this.container.down(".post-approve").show(post.status == "flagged" || post.status == "pending");
  this.container.down(".post-delete").show(post.status != "deleted");
  this.container.down(".post-undelete").show(post.status == "deleted");

  var flagged = this.container.down(".flagged-info");
  flagged.show(post.status == "flagged");
  if(post.status == "flagged" && post.flag_detail)
  {
    var by = flagged.down(".by");
    flagged.down(".flagged-by-box").show(post.flag_detail.user_id != null);
    if(post.flag_detail.user_id != null)
    {
      by.setTextContent(post.flag_detail.flagged_by);
      by.href = "/user/show/" + post.flag_detail.user_id;
    }

    var reason = flagged.down(".reason");
    reason.setTextContent(post.flag_detail.reason);
  }

  /* Moderators can unflag images, and the person who flags an image can unflag it himself. */
  var is_flagger = post.flag_detail && post.flag_detail.user_id == User.get_current_user_id();
  var can_unflag = flagged && (User.is_mod_or_higher() || is_flagger);
  flagged.down(".post-unflag").show(can_unflag);

  var pending = this.container.down(".status-pending");
  pending.show(post.status == "pending");
  this.container.down(".pending-reason-box").show(post.flag_detail && post.flag_detail.reason);
  if(post.flag_detail)
    this.container.down(".pending-reason").setTextContent(post.flag_detail.reason);

  var deleted = this.container.down(".status-deleted");
  deleted.show(post.status == "deleted");
  if(post.status == "deleted")
  {
    var by_container = deleted.down(".by-container");
    by_container.show(post.flag_detail.flagged_by != null);

    var by = by_container.down(".by");
    by.setTextContent(post.flag_detail.flagged_by);
    by.href = "/user/show/" + post.flag_detail.user_id;

    var reason = deleted.down(".reason");
    reason.setTextContent(post.flag_detail.reason);
  }

  this.container.down(".status-held").show(post.is_held);
  var has_permission = User.get_current_user_id() == post.creator_id || User.is_mod_or_higher();
  this.container.down(".activate-post").show(has_permission);
}

BrowserView.prototype.edit_show = function(shown)
{
  var post = Post.posts.get(this.displayed_post_id);
  if(!post)
    shown = false;

  if(!User.is_member_or_higher())
    shown = false;

  this.edit_shown = shown;
  this.container.down(".post-tags-box").show(!shown);
  this.container.down(".post-edit").show(shown);
  if(!shown)
  {
    /* Revert all changes. */
    this.frame_editor.discard();
    return;
  }

  this.select_edit_box(".post-edit-main");

  /* This returns [tag, tag type].  We only want the tag; we call this so we sort the
   * tags consistently. */
  var tags_by_type = Post.get_post_tags_with_type(post);
  var tags = tags_by_type.pluck(0);

  tags = tags.join(" ") + " ";

  this.container.down(".edit-tags").old_value = tags;
  this.container.down(".edit-tags").value = tags;
  this.container.down(".edit-source").value = post.source;
  this.container.down(".edit-parent").value = post.parent_id;
  this.container.down(".edit-shown-in-index").checked = post.is_shown_in_index;

  var rating_class = new Hash({ s: ".edit-safe", q: ".edit-questionable", e: ".edit-explicit" });
  this.container.down(rating_class.get(post.rating)).checked = true;

  this.edit_post_area_changed();

  this.container.down(".edit-tags").focus();
}

/* Set the size of the tag edit area to the size of its contents. */
BrowserView.prototype.edit_post_area_changed = function()
{
  var post_edit = this.container.down(".post-edit");
  var element = post_edit.down(".edit-tags");
  element.style.height = "0px";
  element.style.height = element.scrollHeight + "px";
if(0)
{
  var rating = null;
  var source = null;
  var parent_id = null;
  element.value.split(" ").each(function(tag)
  {
    /* This mimics what the server side does; it does prevent metatags from using
     * uppercase in source: metatags. */
    tag = tag.toLowerCase();
    /* rating:q or just q: */
    var m = tag.match(/^(rating:)?([qse])$/);
    if(m)
    {
      rating = m[2];
      return;
    }

    var m = tag.match(/^(parent):([0-9]+)$/);
    if(m)
    {
      if(m[1] == "parent")
        parent_id = m[2];
    }

    var m = tag.match(/^(source):(.*)$/);
    if(m)
    {
      if(m[1] == "source")
        source = m[2];
    }
  }.bind(this));

  debug("rating: " + rating);
  debug("source: " + source);
  debug("parent: " + parent_id);
}
}

BrowserView.prototype.edit_save = function()
{
  var save_completed = function()
  {
    notice("Post saved");

    /* If we're still showing the post we saved, hide the edit area. */
    if(this.displayed_post_id == post_id)
      this.edit_show(false);
  }.bind(this);
  var post_id = this.displayed_post_id;

  /* If we're in the frame editor, save it.  Don't save the hidden main editor. */
  if(this.frame_editor)
  {
    if(this.frame_editor.is_opened())
    {
      this.frame_editor.save(save_completed);
      return;
    }
  }

  var edit_tags = this.container.down(".edit-tags");
  var tags = edit_tags.value;

  /* Opera doesn't blur the field automatically, even when we hide it later. */
  edit_tags.blur();

  /* Find which rating is selected. */
  var rating_class = new Hash({ s: ".edit-safe", q: ".edit-questionable", e: ".edit-explicit" });
  var selected_rating = "s";
  rating_class.each(function(c) {
    if(this.container.down(c[1]).checked)
      selected_rating = c[0];
  }.bind(this));

  /* update_batch will give us updates for any related posts, as well as the one we're
   * updating. */
  Post.update_batch([{
    id: post_id,
    tags: this.container.down(".edit-tags").value,
    old_tags: this.container.down(".edit-tags").old_value,
    source: this.container.down(".edit-source").value,
    parent_id: this.container.down(".edit-parent").value,
    is_shown_in_index: this.container.down(".edit-shown-in-index").checked,
    rating: selected_rating
  }], save_completed);
}

BrowserView.prototype.window_resize_event = function(e)
{
  if(e.stopped)
    return;
  this.update_image_window_size();
  this.scale_and_position_image(true);
}

BrowserView.prototype.toggle_view_large_image = function()
{
  var post = Post.posts.get(this.displayed_post_id);
  if(post == null)
    return;
  if(this.img == null)
    return;

  if(post.jpeg_url == post.sample_url)
  {
    /* There's no larger version to display. */
    return;
  }

  /* Toggle between the sample and JPEG version. */
  this.set_viewing_larger_version(!this.viewing_larger_version);
  this.set_main_image(post); // XXX frame
}

/* this.image_window_size is the size of the area where the image is visible. */
BrowserView.prototype.update_image_window_size = function()
{
  this.image_window_size = getWindowSize();

  /* If the thumb bar is shown, exclude it from the window height and fit the image
   * in the remainder.  Since the bar is at the bottom, we don't need to do anything to
   * adjust the top. */
  this.image_window_size.height -= this.thumb_bar_height;

  this.image_window_size.height = Math.max(this.image_window_size.height, 0); /* clamp to 0 if there's no space */

  /* When the window size changes, update the navigator since the cursor will resize to
   * match. */
  this.update_navigator();
}

BrowserView.prototype.scale_and_position_image = function(resizing)
{
  var img_box = this.img_box;
  if(!this.img)
    return;
  var original_width = img_box.original_width;
  var original_height = img_box.original_height;

  var post = Post.posts.get(this.displayed_post_id);
  if(!post)
  {
    debug("unexpected: displayed post " + this.displayed_post_id + " unknown");
    return;
  }

  var window_size = this.image_window_size;

  var ratio = 1.0;
  if(!this.viewing_larger_version)
  {
    /* Zoom the image to fit the viewport. */
    var ratio = window_size.width / original_width;
    if (original_height * ratio > window_size.height)
      ratio = window_size.height / original_height;
  }

  ratio *= Math.pow(0.9, this.zoom_level);

  this.displayed_image_width = Math.round(original_width * ratio);
  this.displayed_image_height = Math.round(original_height * ratio);

  this.img.width = this.displayed_image_width;
  this.img.height = this.displayed_image_height;

  this.update_canvas();

  if(this.frame_editor)
    this.frame_editor.set_image_dimensions(this.displayed_image_width, this.displayed_image_height);

  /* If we're resizing and showing the full-size image, don't snap the position
   * back to the default. */
  if(resizing && this.viewing_larger_version)
    return;

  var x = 0.5;
  var y = 0.5;
  if(this.viewing_larger_version)
  {
    /* Align the image to the top of the screen. */
    y = this.image_window_size.height/2;
    y /= this.displayed_image_height;
  }

  this.center_image_on(x, y);
}

/* x and y are [0,1]. */
BrowserView.prototype.update_navigator = function()
{
  if(!this.navigator)
    return;
  if(!this.img)
    return;

  /* The coordinates of the image located at the top-left corner of the window: */
  var scroll_x = -this.img_box.offsetLeft;
  var scroll_y = -this.img_box.offsetTop;

  /* The coordinates at the center of the window: */
  x = scroll_x + this.image_window_size.width/2;
  y = scroll_y + this.image_window_size.height/2;

  var percent_x = x / this.displayed_image_width;
  var percent_y = y / this.displayed_image_height;

  var height_percent = this.image_window_size.height / this.displayed_image_height;
  var width_percent = this.image_window_size.width / this.displayed_image_width;
  this.navigator.image_position_changed(percent_x, percent_y, height_percent, width_percent);
}

/*
 * If Canvas support is available, we can accelerate drawing.
 *
 * Most browsers are slow when resizing large images.  In the best cases, it results in
 * dragging the image around not being smooth (all browsers except Chrome).  In the worst
 * case it causes rendering the page to be very slow; in Chrome, drawing the thumbnail
 * strip under a large resized image is unusably slow.
 *
 * If Canvas support is enabled, then once the image is fully loaded, blit the image into
 * the canvas at the size we actually want to display it at.  This avoids most scaling
 * performance issues, because it's not rescaling the image constantly while dragging it
 * around.
 *
 * Note that if Chrome fixes its slow rendering of boxes *over* the image, then this may
 * be unnecessary for that browser.  Rendering the image itself is very smooth; Chrome seems
 * to prescale the image just once, which is what we're doing.
 *
 * Limitations:
 * - If full-page zooming is being used, it'll still scale at runtime.
 * - We blit the entire image at once.  It's more efficient to blit parts of the image
 *   as necessary to paint, but that's a lot more work.
 * - Canvas won't blit partially-loaded images, so we do nothing until the image is complete.
 */
BrowserView.prototype.update_canvas = function()
{
  if(!this.img.fully_loaded)
  {
    debug("image incomplete; can't render to canvas");
    return false;
  }

  if(!this.canvas)
    return;

  /* If the contents havn't changed, skip the blit.  This happens frequently when resizing
   * the window when not fitting the image to the screen. */
  if(this.canvas.rendered_url == this.img.src &&
      this.canvas.width == this.displayed_image_width &&
      this.canvas.height == this.displayed_image_height)
  {
    // debug(this.canvas.rendered_url + ", " + this.canvas.width + ", " + this.canvas.height)
    // debug("Skipping canvas blit");
    return;
  }

  this.canvas.rendered_url = this.img.src;
  this.canvas.width = this.displayed_image_width;
  this.canvas.height = this.displayed_image_height;
  var ctx = this.canvas.getContext("2d");
  ctx.drawImage(this.img, 0, 0, this.displayed_image_width, this.displayed_image_height);
  this.canvas.show();
  this.img.hide();

  return true;
}


BrowserView.prototype.center_image_on = function(percent_x, percent_y)
{
  var x = percent_x * this.displayed_image_width;
  var y = percent_y * this.displayed_image_height;

  var scroll_x = x - this.image_window_size.width/2;
  scroll_x = Math.round(scroll_x);

  var scroll_y = y - this.image_window_size.height/2;
  scroll_y = Math.round(scroll_y);

  this.img_box.setStyle({left: -scroll_x + "px", top: -scroll_y + "px"});

  this.update_navigator();
}

BrowserView.prototype.cancel_lazily_load = function()
{
  if(this.lazy_load_timer == null)
    return;

   window.clearTimeout(this.lazy_load_timer);
   this.lazy_load_timer = null;
}

/* Update the window title when the display changes. */
WindowTitleHandler = function()
{
  this.searched_tags = "";
  this.post_id = null;
  this.post_frame = null;
  this.pool = null;

  document.on("viewer:searched-tags-changed", function(e) {
    this.searched_tags = e.memo.tags || "";
    this.update();
  }.bindAsEventListener(this));

  document.on("viewer:displayed-post-changed", function(e) {
    this.post_id = e.memo.post_id;
    this.post_frame = e.memo.post_id;
    this.update();
  }.bindAsEventListener(this));

  document.on("viewer:displayed-pool-changed", function(e) {
    this.pool = e.memo.pool;
    this.update();
  }.bindAsEventListener(this));

  this.update();
}

WindowTitleHandler.prototype.update = function()
{
  var post = Post.posts.get(this.post_id);

  if(this.pool)
  {
    var title = this.pool.name.replace(/_/g, " ");

    if(post && post.pool_posts)
    {
      var pool_post = post.pool_posts.get(this.pool.id);
      if(pool_post)
      {
        var sequence = pool_post.sequence;
        title += " ";
        if(sequence.match(/^[0-9]/))
          title += "#";
        title += sequence;
      }
    }
  }
  else
  {
    var title = "/" + this.searched_tags.replace(/_/g, " ");
  }

  title += " - Browse";
  document.title = title;
}

BrowserView.prototype.parent_post_click_event = function(event)
{
  event.stop();

  var post = Post.posts.get(this.displayed_post_id);
  if(post == null || post.parent_id == null)
    return;

  this.set_post(post.parent_id);
}

BrowserView.prototype.child_posts_click_event = function(event)
{
  event.stop();

  /* Search for this post's children.  Set the results mode to center-on-current, so we
   * focus on the current item. */
  document.fire("viewer:perform-search", {
    tags: "parent:" + this.displayed_post_id,
    results_mode: "center-on-current"
  });
}

BrowserView.prototype.select_edit_box = function(className)
{
  if(this.shown_edit_container)
    this.shown_edit_container.hide();
  this.shown_edit_container = this.container.down(className);
  this.shown_edit_container.show();
}

BrowserView.prototype.show_frame_editor = function()
{
  this.select_edit_box(".frame-editor");

  /* If we're displaying a frame and not the whole image, switch to the main image. */
  var post_frame = null;
  if(this.displayed_post_frame != -1)
  {
    post_frame = this.displayed_post_frame;
    document.fire("viewer:set-active-post", {post_id: this.displayed_post_id, post_frame: -1});
  }

  this.frame_editor.open(this.displayed_post_id);
  this.container.down(".post-frames").hide();

  /* If we were on a frame when opened, focus the frame we were on.  Otherwise,
   * leave it on the default. */
  if(post_frame != null)
    this.frame_editor.focus(post_frame);
}

BrowserView.prototype.hide_frame_editor = function()
{
  this.frame_editor.discard();
  this.container.down(".post-frames").show();
}

var Navigator = function(container, target)
{
  this.container = container;
  this.target = target;
  this.hovering = false;
  this.autohide = false;
  this.img = this.container.down(".image-navigator-img");
  this.container.show();

  this.handlers = [];
  this.handlers.push(this.container.on("mousedown", this.mousedown_event.bindAsEventListener(this)));
  this.handlers.push(this.container.on("mouseover", this.mouseover_event.bindAsEventListener(this)));
  this.handlers.push(this.container.on("mouseout", this.mouseout_event.bindAsEventListener(this)));

  this.dragger = new DragElement(this.container, {
    snap_pixels: 0,
    onenddrag: this.enddrag.bind(this),
    ondrag: this.ondrag.bind(this)
  });
}

Navigator.prototype.set_image = function(image_url, width, height)
{
  this.img.src = image_url;
  this.img.width = width;
  this.img.height = height;
}

Navigator.prototype.enable = function(enabled)
{
  this.container.show(enabled);
}

Navigator.prototype.mouseover_event = function(e)
{
  if(e.relatedTarget && e.relatedTarget.isParentNode(this.container))
    return;
  debug("over " + e.target.className + ", " + this.container.className + ", " + e.target.isParentNode(this.container));
  this.hovering = true;
  this.update_visibility();
}

Navigator.prototype.mouseout_event = function(e)
{
  if(e.relatedTarget && e.relatedTarget.isParentNode(this.container))
    return;
  debug("out " + e.target.className);
  this.hovering = false;
  this.update_visibility();
}

Navigator.prototype.mousedown_event = function(e)
{
  var x = e.pointerX();
  var y = e.pointerY();
  var coords = this.get_normalized_coords(x, y);
  this.center_on_position(coords);
}

Navigator.prototype.enddrag = function(e)
{
  this.shift_lock_anchor = null;
  this.locked_to_x = null;
  this.update_visibility();
}

Navigator.prototype.ondrag = function(e)
{
  var coords = this.get_normalized_coords(e.x, e.y);
  if(e.latest_event.shiftKey != (this.shift_lock_anchor != null))
  {
    /* The shift key has been pressed or released. */
    if(e.latest_event.shiftKey)
    {
      /* The shift key was just pressed.  Remember the position we were at when it was
       * pressed. */
      this.shift_lock_anchor = [coords[0], coords[1]];
    }
    else
    {
      /* The shift key was released. */
      this.shift_lock_anchor = null;
      this.locked_to_x = null;
    }
  }

  this.center_on_position(coords);
}

Navigator.prototype.image_position_changed = function(percent_x, percent_y, height_percent, width_percent)
{
  /* When the image is moved or the visible area is resized, update the cursor rectangle. */
  var cursor = this.container.down(".navigator-cursor");
  cursor.setStyle({
    top: this.img.height * (percent_y - height_percent/2) + "px",
    left: this.img.width * (percent_x - width_percent/2) + "px",
    width: this.img.width * width_percent + "px",
    height: this.img.height * height_percent + "px"
  });
}

Navigator.prototype.get_normalized_coords = function(x, y)
{
  var offset = this.img.cumulativeOffset();
  x -= offset.left;
  y -= offset.top;
  x /= this.img.width;
  y /= this.img.height;
  return [x, y];

}

/* x and y are absolute window coordinates. */
Navigator.prototype.center_on_position = function(coords)
{
  if(this.shift_lock_anchor)
  {
    if(this.locked_to_x == null)
    {
      /* Only change the coordinate with the greater delta. */
      var change_x = Math.abs(coords[0] - this.shift_lock_anchor[0]);
      var change_y = Math.abs(coords[1] - this.shift_lock_anchor[1]);

      /* Only lock to moving vertically or horizontally after we've moved a small distance
       * from where shift was pressed. */
      if(change_x > 0.1 || change_y > 0.1)
        this.locked_to_x = change_x > change_y;
    }

    /* If we've chosen an axis to lock to, apply it. */
    if(this.locked_to_x != null)
    {
      if(this.locked_to_x)
        coords[1] = this.shift_lock_anchor[1];
      else
        coords[0] = this.shift_lock_anchor[0];
    }
  }

  coords[0] = Math.max(0, Math.min(coords[0], 1));
  coords[1] = Math.max(0, Math.min(coords[1], 1));

  this.target.fire("viewer:center-on", {x: coords[0], y: coords[1]});
}

Navigator.prototype.set_autohide = function(autohide)
{
  this.autohide = autohide;
  this.update_visibility();
}

Navigator.prototype.update_visibility = function()
{
  var box = this.container.down(".image-navigator-box");
  var visible = !this.autohide || this.hovering || this.dragger.dragging;
  box.style.visibility = visible? "visible":"hidden";
}

Navigator.prototype.destroy = function()
{
  this.dragger.destroy();

  this.handlers.each(function(h) { h.stop(); });
  this.dragger = this.handlers = null;

  this.container.hide();
}


