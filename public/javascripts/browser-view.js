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

  /* True if the post UI is visible.  The viewer:set-post-ui event changes this. */
  this.post_ui_visible = false;

  debug.add_hook(this.get_debug.bind(this));

  this.image_loaded_event = this.image_loaded_event.bindAsEventListener(this);
  this.img = this.container.down(".image");
  this.img.observe("load", this.image_loaded_event);

  this.window_resize_event = this.window_resize_event.bindAsEventListener(this);
  Event.observe(window, "resize", this.window_resize_event);

  this.set_post_ui_event = this.set_post_ui_event.bindAsEventListener(this);
  Event.observe(document, "viewer:set-post-ui", this.set_post_ui_event);

  /* Image controls: */
  this.click_image_zoom_event = this.click_image_zoom_event.bindAsEventListener(this);
  this.container.down(".post-view-larger").observe("click", this.click_image_zoom_event);

  this.image_dragger = new WindowDragElementAbsolute(this.container.down(".image"));
}

/*
 * viewer:set-post-ui
 * { toggle: true } or
 * { set: boolean }
 */
BrowserView.prototype.set_post_ui_event = function(event)
{
  var new_value = this.post_ui_visible;
  if(event.memo.toggle)
    new_value = !this.post_ui_visible;
  else
    new_value = event.memo.set;
  if(new_value == this.post_ui_visible)
    return;

  this.post_ui_visible = new_value;

  this.container.down(".post-info").show(this.post_ui_visible && this.displayed_post_id);
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
    debug.log("skipped-preload(" + post_ids.join(",") + ")");
    this.last_preload_request_active = false;
    return;
  }
  this.last_preload_request_active = true;
  debug.log("preload(" + post_ids.join(",") + ")");
  
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
  debug.log("load needed");

  // If we already have a request in flight, don't start another; wait for the
  // first to finish.
  if(this.current_ajax_request != null)
    return;

  new Ajax.Request("/post/index.json", {
    parameters: { tags: "id:" + post_id, filter: 1 },
    method: "get",

    onCreate: function(resp) {
      this.current_ajax_request = resp.request;
    }.bind(this),

    onSuccess: function(resp) {
      if(this.current_ajax_request != resp.request)
        return;

      /* If no posts were returned, then the post ID we're looking up doesn't exist;
       * treat this as a failure. */
      var posts = resp.responseJSON;
      this.success = posts.length > 0;
      if(!this.success)
      {
        this.failed = true;
        debug.log("requested post " + post_id + " doesn't exist");
        return;
      }

      var post = posts[0];
      Post.register(post);
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
          document.fire("viewer:force-thumb-bar");

        return;
      }

      /* This will either load the post we just finished, or request data for the
       * one we want. */
      this.set_post_content(this.wanted_post_id);
    }.bind(this),

    onFailure: function(resp) {
      notice("Error " + resp.status + " loading post");
    }.bind(this)
  });
}

BrowserView.prototype.set_post_content = function(post_id)
{
  if(post_id == this.displayed_post_id)
    return;

  this.viewing_larger_version = false;

  var post = Post.posts.get(post_id);
  if(post == null)
  {
    if(this.displayed_post_id == null)
    {
      this.container.down(".post-info").hide();
    }
    this.load_post_id_data(post_id);
    return;
  }

  this.displayed_post_id = post_id;
  UrlHash.set({"post-id": post_id});

  /* Clear the previous post, if any. */
  this.img.src = "about:blank";

  if(post)
  {
    this.img.hide();
    this.img.original_width = post.sample_width;
    this.img.original_height = post.sample_height;
    this.img.src = post.sample_url;
    this.img.show();

    // debug.log("set_post_content");
    this.scale_and_position_image();
  }

  // XXX: this is just for voting, handle that separately
  // Post.init_post_show(post_id);

  document.fire("viewer:displayed-post-changed", { post_id: post_id });

  this.container.down(".post-view-larger").pickClassName("enabled", "disabled", post.jpeg_url != post.sample_url);
  this.container.down(".post-info").show(this.post_ui_visible);
  this.container.down(".post-view-larger").href = "/post/show/" + post.id;

  var has_sample = (post.sample_url != post.file_url);
  var has_jpeg = (post.jpeg_url != post.file_url);
  this.container.down(".download-image").show(!has_sample);
  this.container.down(".download-image").href = post.sample_url;
  this.container.down(".download-image-desc").setTextContent(number_to_human_size(post.sample_file_size));
  this.container.down(".download-jpeg").show(has_sample);
  this.container.down(".download-jpeg").href = has_jpeg? post.jpeg_url: post.file_url;
  this.container.down(".download-jpeg-desc").setTextContent(number_to_human_size(has_jpeg? post.jpeg_file_size: post.file_size));
  this.container.down(".download-png").show(has_jpeg);
  this.container.down(".download-png").href = post.file_url;
  this.container.down(".download-png-desc").setTextContent(number_to_human_size(post.file_size));
}

BrowserView.prototype.window_resize_event = function()
{
  debug.log("view resize");
  this.scale_and_position_image(true);
}

BrowserView.prototype.click_image_zoom_event = function(e)
{
  e.stop();
  var post = Post.posts.get(this.displayed_post_id);
  if(post == null)
    return;

  if(post.jpeg_url == post.sample_url)
  {
    /* There's no larger version to display. */
    return;
  }

  /* Toggle between the sample and JPEG version. */
  this.viewing_larger_version = !this.viewing_larger_version;
  if(this.viewing_larger_version)
  {
    this.img.src = post.jpeg_url;
    this.img.original_width = post.jpeg_width;
    this.img.original_height = post.jpeg_height;
  }
  else
  {
    this.img.src = post.sample_url;
    this.img.original_width = post.sample_width;
    this.img.original_height = post.sample_height;
  }

  this.scale_and_position_image();
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
    debug.log("unexpected: displayed post " + this.displayed_post_id + " unknown");
    return;
  }

  var window_size = getWindowSize();
  var ratio = 1.0;
  if(!this.viewing_larger_version)
  {
    /* Zoom the image to fit the viewport. */
    var ratio = window_size.width / original_width;
    if (original_height * ratio > window_size.height)
      ratio = window_size.height / original_height;
  }
//  ratio = Math.min(ratio, 1.0);
  img.width = original_width * ratio;
  img.height = original_height * ratio;

  /* If we're resizing and showing the full-size image, don't snap the position
   * back to the default. */
  if(resizing && this.viewing_larger_version)
    return;

  var offset = img.cumulativeOffset();
  offset.top -= img.offsetTop;
  offset.left -= img.offsetLeft;
  var left_spacing = (window_size.width - img.offsetWidth) / 2;
  var top_spacing = (window_size.height - img.offsetHeight) / 2;
  var scroll_x = offset.left - left_spacing;
  var scroll_y = offset.top - top_spacing;
  img.setStyle({left: -scroll_x + "px", top: -scroll_y + "px"});
}

BrowserView.prototype.set_post = function(post_id)
{
  /* If there was a lazy load pending, cancel it. */
  this.cancel_lazily_load();

  this.wanted_post_id = post_id;

  /* We don't have the node cached.  Open the page from HTML cache or start
   * loading the page as necessary. */
  this.set_post_content(post_id);
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

  var ms = is_cached? 50:500;
  debug.log("post:" + post_id + ":" + is_cached + ":" + ms);

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

  document.observe("viewer:searched-tags-changed", function(e) {
    this.searched_tags = e.memo.tags || "";
    this.update();
  }.bindAsEventListener(this));

  document.observe("viewer:displayed-post-changed", function(e) {
    this.post_id = e.memo.post_id;
    this.update();
  }.bindAsEventListener(this));

  document.observe("viewer:displayed-pool-changed", function(e) {
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

