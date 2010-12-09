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

  /* The post that's currently actually being displayed. */
  this.displayed_post_id = null;

  this.current_ajax_request = null;
  this.last_preload_request = [];
  this.last_preload_request_active = false;

  this.image_pool = new ImgPoolHandler();

  /* True if the post UI is visible. */
  this.post_ui_visible = true;

  debug.handler.add_hook(this.get_debug.bind(this));
  this.update_navigator = this.update_navigator.bind(this);

  Event.on(window, "resize", this.window_resize_event.bindAsEventListener(this));
  document.on("viewer:vote", function(event) { Post.vote($("vote-container"), event.memo.score); });

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

  /* Post editing: */
  var post_edit = this.container.down(".post-edit");
  post_edit.down("FORM").on("submit", function(e) { e.stop(); this.edit_save(); }.bindAsEventListener(this));
  this.container.down(".show-tag-edit").on("click", function(e) { e.stop(); this.edit_show(true); }.bindAsEventListener(this));
  this.container.down(".edit-save").on("click", function(e) { e.stop(); this.edit_save(); }.bindAsEventListener(this));
  this.container.down(".edit-cancel").on("click", function(e) { e.stop(); this.edit_show(false); }.bindAsEventListener(this));

  this.edit_post_area_changed = this.edit_post_area_changed.bind(this);
  post_edit.down(".edit-tags").on("paste", function(e) { this.edit_post_area_changed.defer(); }.bindAsEventListener(this));
  post_edit.down(".edit-tags").on("keydown", function(e) { this.edit_post_area_changed.defer(); }.bindAsEventListener(this));

  this.container.down(".post-edit").on("keydown", function(e) {
    if (e.keyCode == Event.KEY_ESC) { e.stop(); this.edit_show(false); }
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
    this.refresh_post_info(this.displayed_post_id);
  }.bindAsEventListener(this));

  Post.init_vote_widgets();

  this.blacklist_override_post_id = null;
  this.container.down(".show-blacklisted").on("click", function(e) { e.preventDefault(); }.bindAsEventListener(this));
  this.container.down(".show-blacklisted").on("dblclick", function(e) {
    e.stop();
    this.blacklist_override_post_id = this.displayed_post_id;
    var post = Post.posts.get(this.displayed_post_id);
    this.set_main_image(post);
  }.bindAsEventListener(this));


  this.container.on("swipe:horizontal", function(e) { document.fire("viewer:show-next-post", { prev: e.memo.right }); }.bindAsEventListener(this));

  if(Prototype.BrowserFeatures.Touchscreen)
    this.image_swipe = new SwipeHandler(this.container.down(".image-container"));
}

BrowserView.prototype.set_post_ui = function(visible)
{
  /* Disable the post UI by default on touchscreens; we don't have an interface
   * to toggle it. */
  if(Prototype.BrowserFeatures.Touchscreen)
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
  document.fire("viewer:displayed-image-loaded", { post_id: this.displayed_post_id });
}

BrowserView.prototype.get_debug = function()
{
  var s = "wanted: " + this.wanted_post_id + ", displayed: " + this.displayed_post_id;
  if(this.lazy_load_timer)
    s += ", lazy load pending";
  return s;
}

/* Begin preloading the HTML and images for the given post IDs. */
BrowserView.prototype.preload = function(post_ids)
{
  /* We're being asked to preload post_ids.  Only do this if it seems to make sense: if
   * the user is actually traversing posts that are being preloaded.  Look at the previous
   * call to preload().  If it didn't include the current post, then skip the preload. */
  var last_preload_request = this.last_preload_request;
  this.last_preload_request = post_ids;
  if(last_preload_request.indexOf(this.wanted_post_id) == -1)
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
    var post_id = post_ids[i];
    var post = Post.posts.get(post_id);
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

  new Ajax.Request("/post/index.json", {
    parameters: {
      tags: "id:" + post_id,
      api_version: 2,
      filter: 1,
      include_tags: "1",
      include_votes: "1"
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
      this.set_post(this.wanted_post_id);
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
}

BrowserView.prototype.set_main_image = function(post)
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
    if(this.image_dragger)
      this.image_dragger.destroy();
    this.image_dragger = null;
    this.image_pool.release(this.img);
    this.img = null;
  }

  if(this.navigator)
    this.navigator.destroy();
  this.navigator = null;

  /* If this post is blacklisted, show a message instead of displaying it. */
  var hide_post = Post.is_blacklisted(post.id) && post.id != this.blacklist_override_post_id;
  this.container.down(".blacklisted-message").show(hide_post);
  if(hide_post)
    return;

  this.img = this.image_pool.get();
  this.img.className = "main-image";

  /*
   * Work around an iPhone bug.  If a touchstart event is sent to this.img, and then
   * (due to a swipe gesture) we remove the image and replace it with a new one, no
   * touchend is ever delivered, even though it's the containing box listening to the
   * event.  Work around this by setting the image to pointer-events: none, so clicks on
   * the image will actually be sent to the containing box directly.
   *
   * Only do this when using the swipe handler.  The drag handler does use events from
   * the image.
   */
  if(this.image_swipe)
    this.img.setStyle({pointerEvents: "none"});

  if(this.viewing_larger_version && post.jpeg_url)
  {
    this.img.src = post.jpeg_url;
    this.img.original_width = post.jpeg_width;
    this.img.original_height = post.jpeg_height;
    this.img.show();
  }
  else if(!this.viewing_larger_version && post.sample_url)
  {
    this.img.src = post.sample_url;
    this.img.original_width = post.sample_width;
    this.img.original_height = post.sample_height;
    this.img.show();
  }
  else
  {
    /* Having no sample URL is an edge case, usually from deleted posts.  Keep the number
     * of code paths smaller by creating the IMG anyway, but not showing it. */
    this.img.hide();
  }

  this.img.on("load", this.image_loaded_event.bindAsEventListener(this));
  this.container.down(".image-box").appendChild(this.img);

  /* If we're using dragging as a swipe gesture (see SwipeHandler), don't use it for
   * dragging too. */
  if(this.image_swipe == null)
    this.image_dragger = new WindowDragElementAbsolute(this.img, this.update_navigator);

  this.img.on("viewer:center-on", function(e) { this.center_image_on(e.memo.x, e.memo.y); }.bindAsEventListener(this));

  if(this.viewing_larger_version)
  {
    this.navigator = new Navigator(this.container.down(".image-navigator"), this.img, post);
    this.navigator.set_autohide(!this.post_ui_visible);
  }

  this.scale_and_position_image();
}

/* Display post_id. */
BrowserView.prototype.set_post = function(post_id)
{
  /* If there was a lazy load pending, cancel it. */
  this.cancel_lazily_load();

  this.wanted_post_id = post_id;

  if(post_id == this.displayed_post_id)
    return;

  var post = Post.posts.get(post_id);
  if(post == null)
  {
    /* The post we've been asked to display isn't loaded.  Request a load and come back. */
    if(this.displayed_post_id == null)
      this.container.down(".post-info").hide();

    this.load_post_id_data(post_id);
    return;
  }

  this.displayed_post_id = post_id;
  UrlHash.set_deferred({"post-id": post_id});

  this.set_viewing_larger_version(false);

  this.set_main_image(post);

  Post.init_vote(post.id, $("vote-container"));

  document.fire("viewer:displayed-post-changed", { post_id: post_id });

  this.set_post_info();
}

/* If post_id is currently being displayed, update changed post info. */
BrowserView.prototype.refresh_post_info = function(post_id)
{
  if(this.displayed_post_id != post_id)
    return;
  this.set_post_info();
}

/* Set the post info box for the currently displayed post. */
BrowserView.prototype.set_post_info = function()
{
  var post = Post.posts.get(this.displayed_post_id);
  if(!post)
    return;

  this.container.down(".post-id").setTextContent(post.id);
  this.container.down(".post-id-link").href = "/post/show/" + post.id;
  this.container.down(".posted-by").show(post.creator_id != null);
  this.container.down(".posted-at").setTextContent(time_ago_in_words(new Date(post.created_at*1000)));

  if(post.creator_id != null)
  {
    this.container.down(".posted-by").down("A").href = "/user/show/" + post.creator_id;
    this.container.down(".posted-by").down("A").setTextContent(post.author);
  }

  this.container.down(".post-dimensions").setTextContent(post.width + "x" + post.height);
  this.container.down(".post-source").show(post.source != "");
  if(post.source != "")
  {
    var text = post.source;
    var url = null;

    var m = post.source.match(/^http:\/\/.*pixiv\.net\/img\/(\w+)\/(\d+)\.\w+$/);
    if(m)
    {
      text = "pixiv #" + m[2] + " (" + m[1] + ")";
      url = "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=" + m[2];
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

      var a = $(document.createElement("A", ""));
      a.href = "/post/browse#/" + window.encodeURIComponent(tag);
      a.tag_name = tag;
      a.className = "post-tag tag-type-" + type;

      /* Break tags with zero-width spaces, so long tags can be wrapped. */
      var tag_with_breaks = tag.replace(/_/g, "_\u200B");
      a.setTextContent(tag_with_breaks);
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
    by.setTextContent(post.flag_detail.flagged_by);
    by.href = "/user/show/" + post.flag_detail.user_id;

    var reason = flagged.down(".reason");
    reason.setTextContent(post.flag_detail.reason);
  }

  /* Moderators can unflag images, and the person who flags an image can unflag it himself. */
  var is_flagger = post.flag_detail && post.flag_detail.user_id == User.get_current_user_id();
  var can_unflag = flagged && (User.is_mod_or_higher() || is_flagger);
  flagged.down(".post-unflag").show(can_unflag);

  var pending = this.container.down(".status-pending");
  pending.show(post.status == "pending");

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

  this.edit_show(false);
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
    return;

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
  var post_id = this.displayed_post_id;
  
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
  }], function(posts)
  {
    notice("Post saved");

    /* If we're still showing the post we saved, hide the edit area. */
    if(this.displayed_post_id == post_id)
      this.edit_show(false);
  }.bind(this));
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
  this.set_main_image(post);
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
  var img = this.img;
  if(!img)
    return;
  var original_width = img.original_width;
  var original_height = img.original_height;

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

  img.width = original_width * ratio;
  img.height = original_height * ratio;

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
    y /= this.img.height;
  }

  this.center_image_on(x, y);
}

/* x and y are [0,1]. */
BrowserView.prototype.update_navigator = function()
{
  if(!this.navigator)
    return;

  /* The coordinates of the image located at the top-left corner of the window: */
  var scroll_x = -this.img.offsetLeft;
  var scroll_y = -this.img.offsetTop;

  /* The coordinates at the center of the window: */
  x = scroll_x + this.image_window_size.width/2;
  y = scroll_y + this.image_window_size.height/2;

  var percent_x = x / this.img.width;
  var percent_y = y / this.img.height;

  var height_percent = this.image_window_size.height / this.img.height;
  var width_percent = this.image_window_size.width / this.img.width;
  this.navigator.image_position_changed(percent_x, percent_y, height_percent, width_percent);
}

BrowserView.prototype.center_image_on = function(percent_x, percent_y)
{
  var x = percent_x * this.img.width;
  var y = percent_y * this.img.height;

  var scroll_x = x - this.image_window_size.width/2;
  scroll_x = Math.round(scroll_x);

  var scroll_y = y - this.image_window_size.height/2;
  scroll_y = Math.round(scroll_y);

  this.img.setStyle({left: -scroll_x + "px", top: -scroll_y + "px"});

  this.update_navigator();
}

BrowserView.prototype.cancel_lazily_load = function()
{
  if(this.lazy_load_timer == null)
    return;

   window.clearTimeout(this.lazy_load_timer);
   this.lazy_load_timer = null;
}

BrowserView.prototype.lazily_load = function(post_id)
{
  this.cancel_lazily_load();

  /* If we already started the preload for the requested post, then use a small timeout. */
  var is_cached = this.last_preload_request_active && this.last_preload_request.indexOf(post_id) != -1;

  var ms = is_cached? 0:500;

  /* Once lazily_load is called with a new post, we should consistently stay on the current
   * post or change to the new post.  We shouldn't change to a post that was previously
   * requested by lazily_load (due to a background request completing).  Mark whatever post
   * we're currently on as the one we want, until we're able to switch to the new one. */
  this.wanted_post_id = this.displayed_post_id;

  this.lazy_load_post_id = post_id;
  this.lazy_load_timer = window.setTimeout(function() {
    this.lazy_load_timer = null;
    this.set_post(post_id);
  }.bind(this), ms);
}

/* Update the window title when the display changes. */
WindowTitleHandler = function()
{
  this.searched_tags = "";
  this.post_id = null;
  this.pool = null;

  document.on("viewer:searched-tags-changed", function(e) {
    this.searched_tags = e.memo.tags || "";
    this.update();
  }.bindAsEventListener(this));

  document.on("viewer:displayed-post-changed", function(e) {
    this.post_id = e.memo.post_id;
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
    var title = "Browse " + this.pool.name.replace(/_/g, " ");

    if(post && post.pool_post)
    {
      var sequence = post.pool_post.sequence;
      title += " ";
      if(sequence.match(/^[0-9]/))
        title += "#";
      title += sequence;
    }

    document.title = title;
    return;
  }

  var title = "Browse /" + this.searched_tags.replace(/_/g, " ");
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


var Navigator = function(container, target, post)
{
  this.container = container;
  this.target = target;
  this.hovering = false;
  this.img = this.container.down(".image-navigator-img");
  this.img.src = post.preview_url;
  this.img.width = post.actual_preview_width;
  this.img.height = post.actual_preview_height;
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


