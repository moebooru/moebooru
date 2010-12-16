/*
 * Handle the thumbnail view, and navigation for the main view.
 *
 * Handle a large number (thousands) of entries cleanly.  Thumbnail nodes are created
 * as needed, and destroyed when they scroll off screen.  This gives us constant
 * startup time, loads thumbnails on demand, allows preloading thumbnails in advance
 * by creating more nodes in advance, and keeps memory usage constant.
 */
ThumbnailView = function(container, view)
{
  this.container = container;
  this.view = view;
  this.post_ids = [];
  this.post_frames = [];
  this.expanded_post_idx = null;
  this.centered_post_idx = null;
  this.centered_post_offset = 0;
  this.last_mouse_x = 0;
  this.last_mouse_y = 0;
  this.thumb_container_shown = true;
  this.allow_wrapping = true;
  this.thumb_preload_container = new PreloadContainer();
  this.unused_thumb_pool = [];

  /* The [first, end) range of posts that are currently inside .post-browser-posts. */
  this.posts_populated = [0, 0];

  document.on("DOMMouseScroll", this.document_mouse_wheel_event.bindAsEventListener(this));
  document.on("mousewheel", this.document_mouse_wheel_event.bindAsEventListener(this));

  document.on("viewer:displayed-image-loaded", this.displayed_image_loaded_event.bindAsEventListener(this));
  document.on("viewer:set-active-post", function(e) {
    var post_id_and_frame = [e.memo.post_id, e.memo.post_frame];
    this.set_active_post(post_id_and_frame, e.memo.lazy, e.memo.center_thumbs);
  }.bindAsEventListener(this));
  document.on("viewer:show-next-post", function(e) { this.show_next_post(e.memo.prev); }.bindAsEventListener(this));

  document.on("viewer:scroll", function(e) { this.scroll(e.memo.left); }.bindAsEventListener(this));
  document.on("viewer:set-thumb-bar", function(e) {
    if(e.memo.toggle)
      this.show_thumb_bar(!this.thumb_container_shown);
    else
      this.show_thumb_bar(e.memo.set);
  }.bindAsEventListener(this));
  document.on("viewer:loaded-posts", this.loaded_posts_event.bindAsEventListener(this));

  this.hashchange_post_id = this.hashchange_post_id.bind(this);
  UrlHash.observe("post-id", this.hashchange_post_id);
  UrlHash.observe("post-frame", this.hashchange_post_id);

  new DragElement(this.container, { ondrag: this.container_ondrag.bind(this) });

  Element.on(window, "resize", this.window_resize_event.bindAsEventListener(this));

  this.container.on("mousemove", this.container_mousemove_event.bindAsEventListener(this));
  this.container.on("mouseover", this.container_mouseover_event.bindAsEventListener(this));
  this.container.on("click", this.container_click_event.bindAsEventListener(this));
  this.container.on("dblclick", ".post-thumb,.browser-thumb-hover-overlay",
      this.container_dblclick_event.bindAsEventListener(this));

  /* Prevent the default behavior of left-clicking on the expanded thumbnail overlay.  It's
   * handled by container_click_event. */
  this.container.down(".browser-thumb-hover-overlay").on("click", function(event) {
    if(event.isLeftClick())
      event.preventDefault();
  }.bindAsEventListener(this));

  /*
   * For Android browsers, we're set to 150 DPI, which (in theory) scales us to a consistent UI size
   * based on the screen DPI.  This means that we can determine the physical screen size from the
   * window resolution: 150x150 is 1"x1".  Set a thumbnail scale based on this.  On a 320x480 HVGA
   * phone screen the thumbnails are about 2x too big, so set thumb_scale to 0.5.
   *
   * For iOS browsers, there's no way to set the viewport based on the DPI, so it's fixed at 1x.
   * (Note that on Retina screens the browser lies: even though we request 1x, it's actually at
   * 0.5x and our screen dimensions work as if we're on the lower-res iPhone screen.  We can mostly
   * ignore this.)  CSS inches aren't implemented (the DPI is fixed at 96), so that doesn't help us.
   * Fall back on special-casing individual iOS devices.
   */
  this.config = { };
  if(navigator.userAgent.indexOf("iPad") != -1)
  {
    this.config.thumb_scale = 1.0;
  }
  else if(navigator.userAgent.indexOf("iPhone") != -1 || navigator.userAgent.indexOf("iPod") != -1)
  {
    this.config.thumb_scale = 0.5;
  }
  else if(navigator.userAgent.indexOf("Android") != -1)
  {
    /* We may be in landscape or portrait; use out the narrower dimension. */
    var width = Math.min(window.innerWidth, window.innerHeight);

    /* Scale a 320-width screen to 0.5, up to 1.0 for a 640-width screen.  Remember
     * that this width is already scaled by the DPI of the screen due to target-densityDpi,
     * so these numbers aren't actually real pixels, and this scales based on the DPI
     * and size of the screen rather than the pixel count. */
    this.config.thumb_scale = scale(width, 320, 640, 0.5, 1.0);
    debug("Unclamped thumb scale: " + this.config.thumb_scale);

    /* Clamp to [0.5,1.0]. */
    this.config.thumb_scale = Math.min(this.config.thumb_scale, 1.0);
    this.config.thumb_scale = Math.max(this.config.thumb_scale, 0.5);

    debug("startup, window size: " + window.innerWidth + "x" + window.innerHeight);
  }
  else
  {
    /* Unknown device, or not a mobile device. */
    this.config.thumb_scale = 1.0;
  }
  debug("Thumb scale: " + this.config.thumb_scale);

  this.config_changed();

  /* Send the initial viewer:thumb-bar-changed event. */
  this.thumb_container_shown = false;
  this.show_thumb_bar(true);
}

ThumbnailView.prototype.window_resize_event = function(e)
{
  if(e.stopped)
    return;
  if(this.thumb_container_shown)
    this.center_on_post_for_scroll(this.centered_post_idx);
}

/* Show the given posts.  If extending is true, post_ids are meant to extend a previous
 * search; attempt to continue where we left off. */
ThumbnailView.prototype.loaded_posts_event = function(event)
{
  var post_ids = event.memo.post_ids;

  var old_post_ids = this.post_ids;
  var old_centered_post_idx = this.centered_post_idx;
  this.remove_all_posts();

  /* Filter blacklisted posts. */
  post_ids = post_ids.reject(Post.is_blacklisted);

  this.post_ids = [];
  this.post_frames = [];

  for(var i = 0; i < post_ids.length; ++i)
  {
    var post_id = post_ids[i];
    var post = Post.posts.get(post_id);
    if(post.frames.length > 0)
    {
      for(var frame_idx = 0; frame_idx < post.frames.length; ++frame_idx)
      {
        this.post_ids.push(post_id);
        this.post_frames.push(frame_idx);
      }
    }
    else
    {
      this.post_ids.push(post_id);
      this.post_frames.push(null);
    }
  }

  this.allow_wrapping = !event.memo.can_be_extended_further;

  /* Show the results box or "no results".  Do this before updating the results box to make sure
   * the results box isn't hidden when we update, which will make offsetLeft values inside it zero
   * and break things.  If the reason we have no posts is because we didn't do a search at all,
   * don't show no-results. */
  this.container.down(".post-browser-no-results").show(event.memo.tags != null && this.post_ids.length == 0);
  this.container.down(".post-browser-posts").show(this.post_ids.length != 0);

  if(event.memo.extending)
  {
    /*
     * We're extending a previous search with more posts.  The new post list we get may
     * not line up with the old one: the post we're focused on may no longer be in the
     * search, or may be at a different index.
     *
     * Find a nearby post in the new results.  Start searching at the post we're already
     * centered on.  If that doesn't match, move outwards from there.  Only look forward
     * a little bit, or we may match a post that was never seen and jump forward too far
     * in the results.
     */
    var post_id_search_order = sort_array_by_distance(old_post_ids.slice(0, old_centered_post_idx+3), old_centered_post_idx);
    var initial_post_id = null;
    for(var i = 0; i < post_id_search_order.length; ++i)
    {
      var post_id_to_search = post_id_search_order[i];
      var post = Post.posts.get(post_id_to_search);
      if(post != null)
      {
        initial_post_id = post.id;
        break;
      }
    }
    debug("center-on-" + initial_post_id);

    /* If we didn't find anything that matched, go back to the start. */
    if(initial_post_id == null)
    {
      this.centered_post_offset = 0;
      initial_post_id = new_post_ids[0];
    }

    var center_on_post_idx = this.post_ids.indexOf(initial_post_id);
    this.center_on_post_for_scroll(center_on_post_idx);
  }
  else
  {
    /*
     * A new search has completed.
     *
     * results_mode can be one of the following:
     *
     * "center-on-first"
     * Don't change the active post.  Center the results on the first result.  This is used
     * when performing a search by clicking on a tag, where we don't want to center on the
     * post we're on (since it'll put us at some random spot in the results when the user
     * probably wants to browse from the beginning), and we don't want to change the displayed
     * post either.
     *
     * "center-on-current"
     * Don't change the active post.  Center the results on the existing current item,
     * if possible.  This is used when we want to show a new search without disrupting the
     * shown post, such as the "child posts" link in post info, and when loading the initial
     * URL hash when we start up.
     *
     * "jump-to-first"
     * Set the active post to the first result, and center on it.  This is used after making
     * a search in the tags box.
     */
    var results_mode = event.memo.load_options.results_mode || "center-on-current";

    var initial_post_id_and_frame;
    if(results_mode == "center-on-first" || results_mode == "jump-to-first")
      initial_post_id_and_frame = [this.post_ids[0], this.post_frames[0]];
    else
      initial_post_id_and_frame = this.get_current_post_id_and_frame();

    var center_on_post_idx = this.get_post_idx(initial_post_id_and_frame);
    if(center_on_post_idx == null)
      center_on_post_idx = 0;

    this.centered_post_offset = 0;
    this.center_on_post_for_scroll(center_on_post_idx);

    /* If no post is currently displayed and we just completed a search, set the current post.
     * This happens when first initializing; we wait for the first search to complete to retrieve
     * info about the post we're starting on, instead of making a separate query. */
    if(results_mode == "jump-to-first" || this.view.wanted_post_id == null)
      this.set_active_post(initial_post_id_and_frame);
  }

  if(event.memo.tags == null)
  {
    /* If tags is null then no search has been done, which means we're on a URL
     * with a post ID and no search, eg. "/post/browse#12345".  Hide the thumb
     * bar, so we'll just show the post. */
    this.show_thumb_bar(false);
  }
}

ThumbnailView.prototype.container_ondrag = function(e)
{
  this.centered_post_offset -= e.dX;
  this.center_on_post_for_scroll(this.centered_post_idx);
}

ThumbnailView.prototype.container_mouseover_event = function(event)
{
  var li = $(event.target).up(".post-thumb");
  if(!li)
    return;

  this.expand_post(li.post_idx);
}

ThumbnailView.prototype.hashchange_post_id = function()
{
  var post_id_and_frame = this.get_current_post_id_and_frame();
  if(post_id_and_frame[0] == null)
    return;

  /* If we're already displaying this post, ignore the hashchange.  Don't center on the
   * post if this is just a side-effect of clicking a post, rather than the user actually
   * changing the hash. */
  var post_id = post_id_and_frame[0];
  var post_frame = post_id_and_frame[1];
  if(post_id == this.view.displayed_post_id &&
      post_frame == this.view.displayed_post_frame)
  {
//    debug("ignored-hashchange");
    return;
  }

  var new_post_idx = this.get_post_idx(post_id_and_frame);
  this.centered_post_offset = 0;
  this.center_on_post_for_scroll(new_post_idx);
  this.set_active_post(post_id_and_frame);
}

/* Search for the given post ID and frame in the current search results, and return its
 * index.  If the given post isn't in post_ids, return null. */
ThumbnailView.prototype.get_post_idx = function(post_id_and_frame)
{
  var post_id = post_id_and_frame[0];
  var post_frame = post_id_and_frame[1];

  var post_idx = this.post_ids.indexOf(post_id);
  if(post_idx == -1)
    return null;
  if(post_frame == null)
    return post_idx;

  /* A post-frame is specified.  Search for a matching post-id and post-frame.  We assume
   * here that all frames for a post are grouped together in post_ids. */
  if(post_frame != null)
  {
    var post_frame_idx = post_idx;
    while(post_frame_idx < this.post_ids.length && this.post_ids[post_frame_idx] == post_id)
    {
      if(this.post_frames[post_frame_idx] == post_frame)
        return post_frame_idx;
      ++post_frame_idx;
    }
  }

  /* We found a matching post, but not a matching frame.  Return the post. */
  return post_idx;
}

/* Return the post and frame that's currently being displayed in the main view, based
 * on the URL hash.  If no post is displayed and no search results are available,
 * return [null, null]. */
ThumbnailView.prototype.get_current_post_id_and_frame = function()
{
  var post_id = UrlHash.get("post-id");
  if(post_id == null)
  {
    if(this.post_ids.length == 0)
      return [null, null];
    else
      return [this.post_ids[0], this.post_frames[0]];
  }
  post_id = parseInt(post_id);

  var post_frame = UrlHash.get("post-frame");
  if(post_frame != null)
    post_frame = parseInt(post_frame);
  return [post_id, post_frame];
}

/* Track the mouse cursor when it's within the container. */
ThumbnailView.prototype.container_mousemove_event = function(e)
{
  var x = e.pointerX() - document.documentElement.scrollLeft;
  var y = e.pointerY() - document.documentElement.scrollTop;
  this.last_mouse_x = x;
  this.last_mouse_y = y;
}

ThumbnailView.prototype.document_mouse_wheel_event = function(event)
{
  event.stop();

  var val;
  if(event.wheelDelta)
  {
    val = event.wheelDelta;
  } else if (event.detail) {
    val = -event.detail;
  }

  if(this.thumb_container_shown)
    document.fire("viewer:scroll", { left: val >= 0 });
  else
    document.fire("viewer:show-next-post", { prev: val >= 0 });
}

/* Set the post that's shown in the view.  The thumbs will be centered on the post
 * if center_thumbs is true. */
ThumbnailView.prototype.set_active_post = function(post_id_and_frame, lazy, center_thumbs)
{
  this.view.set_post(post_id_and_frame[0], post_id_and_frame[1], lazy);

  if(center_thumbs)
  {
    var post_idx = this.get_post_idx(post_id_and_frame);
    this.centered_post_offset = 0;
    this.center_on_post_for_scroll(post_idx);
  }
}

ThumbnailView.prototype.set_active_post_idx = function(post_idx, lazy, center_thumbs)
{
  if(post_idx == null)
    return;

  var post_id = this.post_ids[post_idx];
  var post_frame = this.post_frames[post_idx];
  this.set_active_post([post_id, post_frame], lazy, center_thumbs);
}

ThumbnailView.prototype.show_next_post = function(prev)
{
  if(this.post_ids.length == 0)
    return;

  var current_idx = this.get_post_idx([this.view.wanted_post_id, this.view.wanted_post_frame]);

  /* If the displayed post isn't in the thumbnails and we're changing posts, start
   * at the beginning. */
  if(current_idx == null)
    current_idx = 0;

  var add = prev? -1:+1;
  if(this.post_frames[current_idx] != this.view.wanted_post_frame && add == +1)
  {
    /*
     * We didn't find an exact match for the frame we're displaying, which usually means
     * we viewed a post frame, and then the user changed the view to the main post, and
     * the main post isn't in the thumbnails.
     *
     * It's strange to be on the main post, to hit pgdn, and to end up on the second frame
     * because the nearest match was the first frame.  Instead, we should end up on the first
     * frame.  To do that, just don't add anything to the index.
     */
    debug("Snapped the display to the nearest frame");
    if(add == +1)
      add = 0;
  }

  var new_idx = current_idx;
  new_idx += add;

  new_idx += this.post_ids.length;
  new_idx %= this.post_ids.length;

  var wrapped = (prev && new_idx > current_idx) || (!prev && new_idx < current_idx);
  if(wrapped)
  {
    /* Only allow wrapping over the edge if we've already expanded the results. */
    if(!this.allow_wrapping)
      return;
    if(!this.thumb_container_shown && prev)
      notice("Continued from the end");
    else if(!this.thumb_container_shown && !prev)
      notice("Starting over from the beginning");
  }

  this.set_active_post_idx(new_idx, true, true);
}

/* Scroll the thumbnail view left or right.  Don't change the displayed post. */
ThumbnailView.prototype.scroll = function(left)
{
  /* There's no point in scrolling the list if it's not visible. */
  if(!this.thumb_container_shown)
    return;
  var new_idx = this.centered_post_idx;

  /* If we're not centered on the post, and we're moving towards the center,
   * don't jump past the post. */
  if(this.centered_post_offset > 0 && left)
    ;
  else if(this.centered_post_offset < 0 && !left)
    ;
  else
    new_idx += (left? -1:+1);

  // Snap to the nearest post.
  this.centered_post_offset = 0;

  /* Wrap the new index. */
  if(new_idx < 0)
  {
    /* Only allow scrolling over the left edge if we've already expanded the results. */
    if(!this.allow_wrapping)
      new_idx = 0;
    else
      new_idx = this.post_ids.length - 1;
  }
  else if(new_idx >= this.post_ids.length)
  {
    if(!this.allow_wrapping)
      new_idx = this.post_ids.length - 1;
    else
      new_idx = 0;
  }

  this.center_on_post_for_scroll(new_idx);
}

/* Hide the hovered post, if any, call center_on_post(post_idx), then hover over the correct post again. */
ThumbnailView.prototype.center_on_post_for_scroll = function(post_idx)
{
  if(this.thumb_container_shown)
    this.expand_post(null);

  this.center_on_post(post_idx);

  /*
   * Now that we've re-centered, we need to expand the correct image.  Usually, we can just
   * wait for the mouseover event to fire, since we hid the expanded thumb overlay and the
   * image underneith it is now under the mouse.  However, browsers are badly broken here.
   * Opera doesn't fire mouseover events when the element under the cursor is hidden.  FF
   * fires the mouseover on hide, but misses the mouseout when the new overlay is shown, so
   * the next time it's hidden mouseover events are lost.
   *
   * Explicitly figure out which item we're hovering over and expand it.
   */
  if(this.thumb_container_shown)
  {
    var element = document.elementFromPoint(this.last_mouse_x, this.last_mouse_y);
    element = $(element);
    if(element)
    {
      var li = element.up(".post-thumb");
      if(li)
        this.expand_post(li.post_idx);
    }
  }
}

ThumbnailView.prototype.remove_post = function(right)
{
  if(this.posts_populated[0] == this.posts_populated[1])
    return false; /* none to remove */

  var node = this.container.down(".post-browser-posts");
  if(right)
  {
    --this.posts_populated[1];
    var node_to_remove = node.lastChild;
  }
  else
  {
    ++this.posts_populated[0];
    var node_to_remove = node.firstChild;
  }

  /* Remove the thumbnail that's no longer visible, and put it in unused_thumb_pool
   * so we can reuse it later.  This won't grow out of control, since we'll always use
   * an item from the pool if available rather than creating a new one. */
  var item = node.removeChild(node_to_remove);
  this.unused_thumb_pool.push(item);
  return true;
}

ThumbnailView.prototype.remove_all_posts = function()
{
  while(this.remove_post(true))
    ;
}

/* Add the next thumbnail to the left or right side. */
ThumbnailView.prototype.add_post_to_display = function(right)
{
  var node = this.container.down(".post-browser-posts");
  if(right)
  {
    var post_idx_to_populate = this.posts_populated[1];
    if(post_idx_to_populate == this.post_ids.length)
      return false;
    ++this.posts_populated[1];

    var thumb = this.create_thumb(post_idx_to_populate);
    node.insertBefore(thumb, null);
  }
  else
  {
    if(this.posts_populated[0] == 0)
      return false;
    --this.posts_populated[0];
    var post_idx_to_populate = this.posts_populated[0];
    var thumb = this.create_thumb(post_idx_to_populate);
    node.insertBefore(thumb, node.firstChild);
  }
  return true;
}

/* Fill the container so post_idx is visible. */
ThumbnailView.prototype.populate_post = function(post_idx)
{
  if(this.is_post_idx_shown(post_idx))
    return;

  /* If post_idx is on the immediate border of what's already displayed, add it incrementally, and
   * we'll cull extra posts later.  Otherwise, clear all of the posts and populate from scratch. */
  if(post_idx == this.posts_populated[1])
  {
    this.add_post_to_display(true);
    return;
  }
  else if(post_idx == this.posts_populated[0])
  {
    this.add_post_to_display(false);
    return;
  }

  /* post_idx isn't on the boundary, so we're jumping posts rather than scrolling.
   * Clear the container and start over. */ 
  this.remove_all_posts();

  var node = this.container.down(".post-browser-posts");

  var thumb = this.create_thumb(post_idx);
  node.appendChild(thumb);
  this.posts_populated[0] = post_idx;
  this.posts_populated[1] = post_idx + 1;
}

ThumbnailView.prototype.is_post_idx_shown = function(post_idx)
{
  if(post_idx >= this.posts_populated[1])
    return false;
  return post_idx >= this.posts_populated[0];
}

/* Return the total width of all thumbs to the left or right of post_idx, not
 * including itself. */
ThumbnailView.prototype.get_width_adjacent_to_post = function(post_idx, right)
{
  var post = $("p" + post_idx);
  if(right)
  {
    var rightmost_node = post.parentNode.lastChild;
    if(rightmost_node == post)
      return 0;
    var right_edge = rightmost_node.offsetLeft + rightmost_node.offsetWidth;
    var center_post_right_edge = post.offsetLeft + post.offsetWidth;
    return right_edge - center_post_right_edge
  }
  else
  {
    return post.offsetLeft;
  }
}

/* Center the thumbnail strip on post_idx.  If post_id isn't in the display, do nothing.
 * Fire viewer:need-more-thumbs if we're scrolling near the edge of the list. */
ThumbnailView.prototype.center_on_post = function(post_idx)
{
  if(!this.post_ids)
  {
    debug("unexpected: center_on_post has no post_ids");
    return;
  }

  var post_id = this.post_ids[post_idx];
  if(Post.posts.get(post_id) == null)
    return;

  if(post_idx > this.post_ids.length*3/4)
  {
    /* We're coming near the end of the loaded posts, so load more. */
    document.fire("viewer:need-more-thumbs", { view: this });
  }

  this.centered_post_idx = post_idx;

  /* If we're not expanded, we can't figure out how to center it since we'll have no width.
   * Also, don't cause thumbnails to be loaded if we're hidden.  Just set centered_post_idx,
   * and we'll come back here when we're displayed. */
  if(!this.thumb_container_shown)
    return;

  /* If centered_post_offset is high enough to put the actual center post somewhere else,
   * adjust it towards zero and change centered_post_idx.  This keeps centered_post_idx
   * pointing at the item that's actually centered. */
  while(1)
  {
    var post = $("p" + this.centered_post_idx);
    if(!post)
      break;
    var pos = post.offsetWidth/2 + this.centered_post_offset;
    if(pos >= 0 && pos < post.offsetWidth)
      break;

    var next_post_idx = this.centered_post_idx + (this.centered_post_offset > 0? +1:-1);
    var next_post = $("p" + next_post_idx);
    if(next_post == null)
      break;

    var current_post_center = post.offsetLeft + post.offsetWidth/2;
    var next_post_center = next_post.offsetLeft + next_post.offsetWidth/2;
    var distance = next_post_center - current_post_center;
    this.centered_post_offset -= distance;
    this.centered_post_idx = next_post_idx;

    post_idx = this.centered_post_idx;
    break;
  }

  this.populate_post(post_idx);

  /* Make sure that we have enough posts populated around the one we're centering
   * on to fill the display.  If we have too many nodes, remove some. */
  for(var direction = 0; direction < 2; ++direction)
  {
    var right = !!direction;

    /* We need at least this.container.offsetWidth/2 in each direction.  Load a little more, to
     * reduce flicker. */
    var minimum_distance = this.container.offsetWidth/2;
    minimum_distance *= 1.25;
    var maximum_distance = minimum_distance + 500;
    while(true)
    {
      var added = false;
      var width = this.get_width_adjacent_to_post(post_idx, right);

      /* If we're offset to the right then we need more data to the left, and vice versa. */
      width += this.centered_post_offset * (right? -1:+1);
      if(width < 0)
        width = 1;

      if(width < minimum_distance)
      {
        /* We need another post.  Stop if there are no more posts to add. */
        if(!this.add_post_to_display(right))
          break;
        added = false;
      }
      else if(width > maximum_distance)
      {
        /* We have a lot of posts off-screen.  Remove one. */
        this.remove_post(right);

        /* Sanity check: we should never add and remove in the same direction.  If this
         * happens, the distance between minimum_distance and maximum_distance may be less
         * than the width of a single thumbnail. */
        if(added)
        {
          alert("error");
          break;
        }
      }
      else
      {
        break;
      }
    }
  }

  this.preload_thumbs();

  /* We always center the thumb.  Don't clamp to the edge when we're near the first or last
   * item, so we always have empty space on the sides for expanded landscape thumbnails to
   * be visible. */
  var thumb = $("p" + post_idx);
  var center_on_position = this.container.offsetWidth/2;

  var shift_pixels_right = center_on_position - thumb.offsetWidth/2 - thumb.offsetLeft;
  shift_pixels_right -= this.centered_post_offset;
  shift_pixels_right = Math.round(shift_pixels_right);

  var node = this.container.down(".post-browser-scroller");
  node.setStyle({left: shift_pixels_right + "px"});
}

/* Preload thumbs on the boundary of what's actually displayed. */
ThumbnailView.prototype.preload_thumbs = function()
{
  var post_idxs = [];
  for(var i = 0; i < 5; ++i)
  {
    var preload_post_idx = this.posts_populated[0] - i - 1;
    if(preload_post_idx >= 0)
      post_idxs.push(preload_post_idx);

    var preload_post_idx = this.posts_populated[1] + i;
    if(preload_post_idx < this.post_ids.length)
      post_idxs.push(preload_post_idx);
  }

  /* Remove any preloaded thumbs that are no longer in the preload list. */
  this.thumb_preload_container.get_all().each(function(element) {
    var post_idx = element.post_idx;
    if(post_idxs.indexOf(post_idx) != -1)
    {
      /* The post is staying loaded.  Clear the value in post_idxs, so we don't load it
       * again down below. */
      post_idxs[post_idx] = null;
      return;
    }

    /* The post is no longer being preloaded.  Remove the preload. */
    this.thumb_preload_container.cancel_preload(element);
  }.bind(this));

  /* Add new preloads. */
  for(var i = 0; i < post_idxs.length; ++i)
  {
    var post_idx = post_idxs[i];
    if(post_idx == null)
      continue;

    var post_id = this.post_ids[post_idx];
    var post = Post.posts.get(post_id);

    var post_frame = this.post_frames[post_idx];
    var url;
    if(post_frame != null)
      url = post.frames[post_frame].preview_url;
    else
      url = post.preview_url;

    var element = this.thumb_preload_container.preload(url);
    element.post_idx = post_idx;
  }
}

ThumbnailView.prototype.expand_post = function(post_idx)
{
  /* Thumbs on click for touchpads doesn't make much sense anyway--touching the thumb causes it
   * to be loaded.  It also triggers a bug in iPhone WebKit (covering up the original target of
   * a mouseover during the event seems to cause the subsequent click event to not be delivered).
   * Just disable hover thumbnails for touchscreens.  */
  if(Prototype.BrowserFeatures.Touchscreen)
    return;

  if(!this.thumb_container_shown)
    return;

  var post_id = this.post_ids[post_idx];

  var overlay = this.container.down(".browser-thumb-hover-overlay");
  overlay.hide();
  overlay.down("IMG").src = "about:blank";

  this.expanded_post_idx = post_idx;
  if(post_idx == null)
    return;

  var post = Post.posts.get(post_id);
  if(post.status == "deleted")
    return;

  var thumb = $("p" + post_idx);

  var bottom = this.container.down(".browser-bottom-bar").offsetHeight;
  overlay.style.bottom = bottom + "px";

  var post_frame = this.post_frames[post_idx];
  var image_width, image_url;
  if(post_frame != null)
  {
    var frame = post.frames[post_frame];
    image_width = frame.preview_width;
    image_url = frame.preview_url;
  }
  else
  {
    image_width = post.actual_preview_width;
    image_url = post.preview_url;
  }

  var left = thumb.cumulativeOffset().left - image_width/2 + thumb.offsetWidth/2;
  overlay.style.left = left + "px";

  /* If the hover thumbnail overflows the right edge of the viewport, it'll extend the document and
   * allow scrolling to the right, which we don't want.  overflow: hidden doesn't fix this, since this
   * element is absolutely positioned.  Set the max-width to clip the right side of the thumbnail if
   * necessary. */
  var max_width = document.viewport.getDimensions().width - left;
  overlay.style.maxWidth = max_width + "px";

  overlay.href = "/post/browse#" + post.id;
  if(post_frame != null)
    overlay.href += "-" + post_frame;
  overlay.down("IMG").src = image_url;
  overlay.show();
}

ThumbnailView.prototype.create_thumb = function(post_idx)
{
  var post_id = this.post_ids[post_idx];
  var post_frame = this.post_frames[post_idx];

  var post = Post.posts.get(post_id);

  /*
   * Reuse thumbnail blocks that are no longer in use, to avoid WebKit memory leaks: it
   * doesn't like creating and deleting lots of images (or blocks with images inside them).
   *
   * Thumbnails are hidden until they're loaded, so we don't show ugly load-borders.  This
   * also keeps us from showing old thumbnails before the new image is loaded.  Use visibility:
   * hidden, not display: none, or the size of the image won't be defined, which breaks
   * center_on_post.
   */
  if(this.unused_thumb_pool.length == 0)
  {
    var div =
      '<div class="inner">' +
        '<a class="thumb" tabindex="-1">' +
          '<img alt="" class="preview" onload="this.style.visibility = \'visible\';">' +
        '</a>' +
      '</div>';
    var item = $(document.createElement("li"));
    item.innerHTML = div;
    item.className = "post-thumb";
  }
  else
  {
    var item = this.unused_thumb_pool.pop();
  }
    
  item.id = "p" + post_idx;
  item.post_idx = post_idx;
  item.down("A").href = "/post/browse#" + post.id;
  if(post_frame != null)
    item.down("A").href += "-" + post_frame;

  /* If the image is already what we want, then leave it alone.  Setting it to what it's
   * already set to won't necessarily cause onload to be fired, so it'll never be set
   * back to visible. */
  var img = item.down("IMG");
  var url;
  if(post_frame != null)
    url = post.frames[post_frame].preview_url;
  else
    url = post.preview_url;
  if(img.src != url)
  {
    img.style.visibility = "hidden";
    img.src = url;
  }

  this.set_thumb_dimensions(item);
  return item;
}

ThumbnailView.prototype.set_thumb_dimensions = function(li)
{
  var post_idx = li.post_idx;
  var post_id = this.post_ids[post_idx];
  var post_frame = this.post_frames[post_idx];
  var post = Post.posts.get(post_id);

  var width, height;
  if(post_frame != null)
  {
    var frame = post.frames[post_frame];
    width = frame.preview_width;
    height = frame.preview_height;
  }
  else
  {
    width = post.actual_preview_width;
    height = post.actual_preview_height;
  }

  width *= this.config.thumb_scale;
  height *= this.config.thumb_scale;

  /* This crops blocks that are too wide, but doesn't pad them if they're too
   * narrow, since that creates odd spacing. 
   *
   * If the height of this block is changed, adjust .post-browser-posts-container in
   * config_changed. */
  var block_size = [Math.min(width, 200 * this.config.thumb_scale), 200 * this.config.thumb_scale];
  var crop_left = Math.round((width - block_size[0]) / 2);
  var pad_top = Math.max(0, block_size[1] - height);

  var inner = li.down(".inner");
  inner.actual_width = block_size[0];
  inner.actual_height = block_size[1];
  inner.setStyle({width: block_size[0] + "px", height: block_size[1] + "px"});

  var img = inner.down("img");
  img.width = width;
  img.height = height;
  img.setStyle({marginTop: pad_top + "px", marginLeft: -crop_left + "px"});
}

ThumbnailView.prototype.config_changed = function()
{
  /* Adjust the size of the container to fit the thumbs at the current scale.  They're the
   * height of the thumb block, plus ten pixels for padding at the top and bottom. */
  var container_height = 200*this.config.thumb_scale + 10;
  this.container.down(".post-browser-posts-container").setStyle({height: container_height + "px"});

  this.container.select("LI.post-thumb").each(this.set_thumb_dimensions.bind(this));

  this.center_on_post_for_scroll(this.centered_post_idx);
}

/* Handle clicks and doubleclicks on thumbnails.  These events are handled by
 * the container, so we don't need to put event handlers on every thumb. */
ThumbnailView.prototype.container_click_event = function(event)
{
  /* Ignore the click if it was stopped by the DragElement. */
  if(event.stopped)
    return;

  if($(event.target).up(".browser-thumb-hover-overlay"))
  {
    /* The hover overlay was clicked.  When the user clicks a thumbnail, this is
     * usually what happens, since the hover overlay covers the actual thumbnail. */
    this.set_active_post_idx(this.expanded_post_idx);
    event.preventDefault();
    return;
  }

  var li = $(event.target).up(".post-thumb");
  if(li == null)
    return;

  /* An actual thumbnail was clicked.  This can happen if we don't have the expanded
   * thumbnails for some reason. */
  event.preventDefault();
  this.set_active_post_idx(li.post_idx);
}

ThumbnailView.prototype.container_dblclick_event = function(event)
{
  if(event.button)
    return;

  event.preventDefault();
  this.show_thumb_bar(false);
}

ThumbnailView.prototype.show_thumb_bar = function(shown)
{
  if(this.thumb_container_shown == shown)
    return;
  this.thumb_container_shown = shown;
  this.container.show(shown);

  /* If the centered post was changed while we were hidden, it wasn't applied by
   * center_on_post, so do it now. */
  this.center_on_post_for_scroll(this.centered_post_idx);

  document.fire("viewer:thumb-bar-changed", {
    shown: this.thumb_container_shown,
    height: this.thumb_container_shown? this.container.offsetHeight:0
  });
}

/* Return the next or previous post, wrapping around if necessary. */
ThumbnailView.prototype.get_adjacent_post_idx_wrapped = function(post_idx, next)
{
  post_idx += next? +1:-1;
  post_idx = (post_idx + this.post_ids.length) % this.post_ids.length;
  return post_idx;
}

ThumbnailView.prototype.displayed_image_loaded_event = function(event)
{
  /* If we don't have a loaded search, then we don't have any nearby posts to preload. */
  if(this.post_ids == null)
    return;

  var post_id = event.memo.post_id;
  var post_frame = event.memo.post_frame;
  var post_idx = this.get_post_idx([post_id, post_frame]);
  if(post_idx == null)
    return;

  /*
   * The image in the post we're displaying is finished loading.
   *
   * Preload the next and previous posts.  Normally, one or the other of these will
   * already be in cache.
   *
   * Include the current post in the preloads, so if we switch from a frame back to
   * the main image, the frame itself will still be loaded.
   */
  var post_ids_to_preload = [];
  post_ids_to_preload.push([this.post_ids[post_idx], this.post_frames[post_idx]]);
  var adjacent_post_idx = this.get_adjacent_post_idx_wrapped(post_idx, true);
  if(adjacent_post_idx != null)
    post_ids_to_preload.push([this.post_ids[adjacent_post_idx], this.post_frames[adjacent_post_idx]]);
  var adjacent_post_idx = this.get_adjacent_post_idx_wrapped(post_idx, false);
  if(adjacent_post_idx != null)
    post_ids_to_preload.push([this.post_ids[adjacent_post_idx], this.post_frames[adjacent_post_idx]]);
  this.view.preload(post_ids_to_preload);
}


/* This handler handles global keypress bindings, and fires viewer: events. */
function InputHandler()
{
  TrackFocus();

  /*
   * Keypresses are aggrevating:
   *
   * Opera can only stop key events from keypress, not keydown.
   *
   * Chrome only sends keydown for non-alpha keys, not keypress.
   *
   * In Firefox, keypress's keyCode value for non-alpha keys is always 0.
   *
   * Alpha keys can always be detected with keydown.  Don't use keypress; Opera only provides
   * charCode to that event, and it's affected by the caps state, which we don't want.
   *
   * Use OnKey for alpha key bindings.  For other keys, use keypress in Opera and FF and
   * keydown in other browsers.
   */
  var keypress_event_name = window.opera || Prototype.Browser.Gecko? "keypress":"keydown";
  document.on(keypress_event_name, this.document_keypress_event.bindAsEventListener(this));
}

InputHandler.prototype.handle_keypress = function(e)
{
  var key = e.charCode;
  if(!key)
    key = e.keyCode; /* Opera */
  if(key == Event.KEY_ESC)
  {
    if(document.focusedElement && document.focusedElement.blur && !document.focusedElement.hasClassName("no-blur-on-escape"))
    {
      document.focusedElement.blur();
      return true;
    }
  }

  var target = e.target;
  if(target.tagName == "INPUT" || target.tagName == "TEXTAREA")
    return false;

  if(key == 63) // ?, f
  {
    debug("xxx");
    document.fire("viewer:show-help");
    return true;
  }

  if (e.shiftKey || e.altKey || e.ctrlKey || e.metaKey)
    return false;
  var grave_keycode = Prototype.Browser.WebKit? 192: 96;
  if(key == 32) // space
    document.fire("viewer:set-thumb-bar", { toggle: true });
  else if(key == 49) // 1
    document.fire("viewer:vote", { score: 1 });
  else if(key == 50) // 2
    document.fire("viewer:vote", { score: 2 });
  else if(key == 51) // 3
    document.fire("viewer:vote", { score: 3 });
  else if(key == grave_keycode) // `
    document.fire("viewer:vote", { score: 0 });
  else if(key == 65 || key == 97) // A, b
    document.fire("viewer:show-next-post", { prev: true });
  else if(key == 69 || key == 101) // E, e
    document.fire("viewer:edit-post");
  else if(key == 83 || key == 115) // S, s
    document.fire("viewer:show-next-post", { prev: false });
  else if(key == 70 || key == 102) // F, f
    document.fire("viewer:focus-tag-box");
  else if(key == 86 || key == 118) // V, v
    document.fire("viewer:view-large-toggle");
  else if(key == Event.KEY_PAGEUP)
    document.fire("viewer:show-next-post", { prev: true });
  else if(key == Event.KEY_PAGEDOWN)
    document.fire("viewer:show-next-post", { prev: false });
  else if(key == Event.KEY_LEFT)
    document.fire("viewer:scroll", { left: true });
  else if(key == Event.KEY_RIGHT)
    document.fire("viewer:scroll", { left: false });
  else
    return false;
  return true;
}

InputHandler.prototype.document_keypress_event = function(e)
{
  //alert(e.charCode + ", " + e.keyCode);
  if(this.handle_keypress(e))
    e.stop();
}

