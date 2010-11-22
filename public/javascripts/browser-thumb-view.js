PostLoader = function()
{
  this.need_more_post_data = this.need_more_post_data.bindAsEventListener(this);
  document.observe("viewer:need-more-thumbs", this.need_more_post_data);

  this.hashchange_tags = this.hashchange_tags.bind(this);
  UrlHash.observe("tags", this.hashchange_tags);

  this.load(false);
}

PostLoader.prototype.need_more_post_data = function()
{
  /* We'll receive this message often once we're close to needing more posts.  Only
   * start loading more data the first time. */
  if(this.loaded_extended_results)
    return;

//  debug.log("more-data");
  this.load(true);
}


PostLoader.prototype.server_load_pool = function(pool_id)
{
  new Ajax.Request("/pool/show.json", {
    parameters: { id: pool_id },
    method: "get",
    onCreate: function(resp) {
      this.current_ajax_requests.push(resp.request);
    }.bind(this),

    onComplete: function(resp) {
      this.current_ajax_requests = this.current_ajax_requests.without(resp.request);
      this.request_finished();
    }.bind(this),

    onSuccess: function(resp) {
      if(this.current_ajax_requests.indexOf(resp.request) == -1)
        return;

      this.result.pool = resp.responseJSON;
    }.bind(this)
  });
}

PostLoader.prototype.server_load_posts = function(limit, extending)
{
  var tags = this.result.tags;

  var search = tags + " limit:" + limit;
  this.result.extending = extending;

  new Ajax.Request("/post/index.json", {
    parameters: { tags: search, filter: 1 },
    method: "get",

    onCreate: function(resp) {
      this.current_ajax_requests.push(resp.request);
    }.bind(this),

    onComplete: function(resp) {
      this.current_ajax_requests = this.current_ajax_requests.without(resp.request);
      this.request_finished();
    }.bind(this),

    onSuccess: function(resp) {
      if(this.current_ajax_requests.indexOf(resp.request) == -1)
        return;
    
      this.result.posts = resp.responseJSON;
    }.bind(this),

    onFailure: function(resp) {
      notice("Error " + resp.status + " loading posts");
    }.bind(this)
  });
}

PostLoader.prototype.request_finished = function()
{
  if(this.current_ajax_requests.length)
    return;

  var new_post_ids = [];
  if(this.result.posts)
  {
    for(var i = 0; i < this.result.posts.length; ++i)
    {
      var post = this.result.posts[i];
      Post.register(post);
      new_post_ids.push(post.id);
    }
  }

  document.fire("viewer:displayed-pool-changed", { pool: this.result.pool });
  document.fire("viewer:searched-tags-changed", { tags: this.result.tags });

  /* Tell the thumbnail viewer whether it should allow scrolling over the left side. */
  var can_be_extended_further = new_post_ids.length > 0 && !this.result.extending && !this.result.pool;

  document.fire("viewer:loaded-posts", {
    post_ids: new_post_ids,
    pool: this.result.pool,
    extending: this.result.extending,
    can_be_extended_further: can_be_extended_further
  });

  this.result = null;
}


/* If extending is true, load a larger set of posts. */
PostLoader.prototype.load = function(extending)
{
  /* If neither a search nor a post-id is specified, set a default search. */
  if(!extending && UrlHash.get("tags") == null && UrlHash.get("post-id") == null)
  {
    UrlHash.set({tags: ""});

    /* We'll receive another hashchange message for setting "tags".  Don't load now or we'll
     * end up loading twice. */
    return;
  }

  this.loaded_extended_results = extending;

  /* Discard any running AJAX requests. */
  this.current_ajax_requests = [];

  this.result = {};
  this.result.tags = UrlHash.get("tags");

  if(this.result.tags == null)
  {
    /* If no search is specified, don't run one; return empty results. */
    this.request_finished();
    return;
  }

  /* See if we have a pool search.  This only checks for pool:id searches, not pool:*name* searches;
   * we want to know if we're displaying posts only from a single pool. */
  var pool_id = null;
  this.result.tags.split(" ").each(function(tag) {
    var m = tag.match(/^pool:(\d+)/);
    if(!m)
      return;
    pool_id = parseInt(m[1]);
  });

  /* If we're loading from a pool, load the pool's data. */
  if(pool_id != null)
    this.server_load_pool(pool_id);

  this.result.extending = extending;

  /* Load the posts to display.  If we're loading a pool, load all posts (up to 1000);
   * otherwise set a limit. */
  var limit = extending? 1000:100;
  if(pool_id != null)
    limit = 1000;
  this.server_load_posts(limit, extending);
}

PostLoader.prototype.hashchange_tags = function()
{
  this.load(false);
}

   
  
  
  
  
  
  
  
  
  
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
  this.post_ids = null; /* set by init() */
  this.expanded_post_id = null;
  this.centered_post_id = null;
  this.last_mouse_x = 0;
  this.last_mouse_y = 0;
  this.thumb_container_shown = true;
  this.allow_wrapping = true;
  this.thumb_preloads = new Hash();
  this.thumb_preload_container = Preload.create_preload_container();

  /* The [first, end) range of posts that are currently inside .post-browser-posts. */
  this.posts_populated = [0, 0];

  this.container_click_event = this.container_click_event.bindAsEventListener(this);
  this.container_dblclick_event = this.container_dblclick_event.bindAsEventListener(this);
  this.container_mouse_wheel_event = this.container_mouse_wheel_event.bindAsEventListener(this);
  this.document_mouse_wheel_event = this.document_mouse_wheel_event.bindAsEventListener(this);
  this.document_dblclick_event = this.document_dblclick_event.bindAsEventListener(this);

  this.container.observe("DOMMouseScroll", this.container_mouse_wheel_event);
  this.container.observe("mousewheel", this.container_mouse_wheel_event);

  document.observe("DOMMouseScroll", this.document_mouse_wheel_event);
  document.observe("mousewheel", this.document_mouse_wheel_event);

  Post.observe_finished_loading(this.displayed_image_finished_loading.bind(this));

  OnKey(65, { AlwaysAllowOpera: true, allowRepeat: true }, function(e) { this.show_next_post(true); }.bind(this));
  OnKey(83, { AlwaysAllowOpera: true, allowRepeat: true }, function(e) { this.show_next_post(false); }.bind(this));
//  OnKey(32, { AlwaysAllowOpera: true }, function(e) { this.toggle_thumb_bar(); }.bind(this));

  /* We need to watch for space presses during keypress rather than keydown, since
   * for some reason cancelling during the keydown event won't prevent the browser
   * default behavior like it probably should. */
  this.document_keypress_event = this.document_keypress_event.bindAsEventListener(this);
  Element.observe(document, "keypress", this.document_keypress_event);

  this.hashchange_post_id = this.hashchange_post_id.bind(this);
  UrlHash.observe("post-id", this.hashchange_post_id);

  Element.observe(document, "dblclick", this.document_dblclick_event);

  this.container_mousemove_event = this.container_mousemove_event.bindAsEventListener(this);
  this.container.observe("mousemove", this.container_mousemove_event);

  this.container_mouseover_event = this.container_mouseover_event.bindAsEventListener(this);
  this.container.observe("mouseover", this.container_mouseover_event);

  this.container.observe("click", this.container_click_event);
  this.container.observe("dblclick", this.container_dblclick_event);

  this.loaded_posts_event = this.loaded_posts_event.bindAsEventListener(this);
  document.observe("viewer:loaded-posts", this.loaded_posts_event);
}

ThumbnailView.prototype.loaded_posts_event = function(event)
{
  this.init(event.memo.post_ids, event.memo.extending, event.memo.can_be_extended_further);
}

/* Show the given posts.  If extending is true, post_ids are meant to extend a previous
 * search; attempt to continue where we left off. */
ThumbnailView.prototype.init = function(post_ids, extending, can_be_extended_further)
{
  var old_post_ids = this.post_ids || [];
  var old_centered_post_idx = old_post_ids.indexOf(this.centered_post_id);
  this.remove_all_posts();

  this.post_ids = post_ids;
  this.allow_wrapping = !can_be_extended_further;

  if(extending)
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
    debug.log("center-on-" + initial_post_id);

    /* If we didn't find anything that matched, go back to the start. */
    if(initial_post_id == null)
      initial_post_id = new_post_ids[0];

    this.center_on_post(initial_post_id);
  }
  else
  {
    var initial_post_id = this.get_current_post_id();
    if(this.post_ids.indexOf(initial_post_id) == -1)
      this.center_on_post(this.post_ids[0]);
    else
      this.center_on_post(initial_post_id);
    this.set_active_post(initial_post_id);
  }
}

ThumbnailView.prototype.container_mouseover_event = function(event)
{
  var li = event.target.up(".post-thumb");
  if(!li)
    return;
  var post_id = li.post_id;

  this.expand_post(post_id);
}

ThumbnailView.prototype.document_keypress_event = function(e) {
  var key = e.charCode;
  if(key == null)
    key = e.keyCode; /* Opera */
  if (key != 32)
    return;
  if (e.shiftKey || e.altKey || e.ctrlKey || e.metaKey)
    return;
  var target = e.target;
  if(target.tagName == "INPUT" || target.tagName == "TEXTAREA")
    return;

  this.toggle_thumb_bar();
  e.stop();
}


ThumbnailView.prototype.hashchange_post_id = function()
{
  var new_post_id = this.get_current_post_id();

  /* If we're already displaying this post, ignore the hashchange.  Don't center on the
   * post if this is just a side-effect of clicking a post, rather than the user actually
   * changing the hash. */
  if(new_post_id == this.view.displayed_post_id)
  {
    debug.log("ignored-hashchange");
    return;
  }

  this.center_on_post(new_post_id);
  this.set_active_post(new_post_id, true);
}

/* Return the post ID that's currently being displayed in the main view, based
 * on the URL hash.  If no post is specified, return -1. */
ThumbnailView.prototype.get_current_post_id = function()
{
  var post_id = UrlHash.get("post-id");
  if(post_id == null)
    return this.post_ids[0];

  post_id = parseInt(post_id);
  return post_id;
}

/* Track the mouse cursor when it's within the container. */
ThumbnailView.prototype.container_mousemove_event = function(e)
{
  var x = e.pointerX() - document.documentElement.scrollLeft;
  var y = e.pointerY() - document.documentElement.scrollTop;
  this.last_mouse_x = x;
  this.last_mouse_y = y;
}

ThumbnailView.prototype.container_mouse_wheel_event = function(event)
{
  event.stop();

  var val;
  if(event.wheelDelta)
  {
    val = event.wheelDelta;
  } else if (event.detail) {
    val = -event.detail;
  }

  this.scroll(val >= 0);
}

ThumbnailView.prototype.document_mouse_wheel_event = function(event)
{
  event.preventDefault();

  var val;
  if(event.wheelDelta)
  {
    val = event.wheelDelta;
  } else if (event.detail) {
    val = -event.detail;
  }

  this.show_next_post(val >= 0);
}

/* Double-clicking the image shows the UI. */
ThumbnailView.prototype.document_dblclick_event = function(event)
{
  if(event.target.id != "image")
    return;

  event.stop();
  this.toggle_thumb_bar();
}

ThumbnailView.prototype.set_active_post = function(post_id, lazy)
{
  if(post_id == null)
    return;

  this.active_post_id = post_id;

  if(lazy)
  {
    /* Ask the pool browser to load the new post, with a delay in case we're
     * scrolling quickly. */
    this.view.lazily_load(post_id);
  } else {
    this.view.set_post(post_id);
  }
}

ThumbnailView.prototype.show_next_post = function(up)
{
  var active_post_id = this.active_post_id;
  var current_idx = this.post_ids.indexOf(active_post_id);

  /* If the displayed post isn't in the thumbnails and we're changing posts, start
   * at the beginning. */
  if(current_idx == -1)
    current_idx = 0;
  var new_idx = current_idx + (up? -1:+1);

  if(this.post_ids.length == 0)
    return;

  if(new_idx < 0)
  {
    /* Only allow wrapping over the edge if we've already expanded the results. */
    if(!this.allow_wrapping)
      return;
    if(!this.thumb_container_shown)
      notice("Continued from the end");
    new_idx = this.post_ids.length - 1;
  }
  else if(new_idx >= this.post_ids.length)
  {
    if(!this.allow_wrapping)
      return;
    if(!this.thumb_container_shown)
      notice("Starting over from the beginning");
    new_idx = 0;
  }

  var new_post_id = this.post_ids[new_idx];
  this.center_on_post(new_post_id);
  this.expand_post(new_post_id);
  this.set_active_post(new_post_id, true);
}

/* Scroll the thumbnail view left or right.  Don't change the displayed post. */
ThumbnailView.prototype.scroll = function(up)
{
  var current_post_id = this.centered_post_id;
  var current_idx = this.post_ids.indexOf(current_post_id);
  var new_idx = current_idx + (up? -1:+1);

  /* Wrap the new index. */
  if(new_idx < 0)
  {
    /* Only allow scrolling over the left edge if we've already expanded the results. */
    if(!this.allow_wrapping)
      return;
    new_idx = this.post_ids.length - 1;
  }
  else if(new_idx >= this.post_ids.length)
  {
    if(!this.allow_wrapping)
      return;
    new_idx = 0;
  }

  var new_post_id = this.post_ids[new_idx];
  this.center_on_post_for_scroll(new_post_id);
}

/* This calls center_on_post, and also unexpands and reexpands posts correctly to avoid flicker. */
ThumbnailView.prototype.center_on_post_for_scroll = function(post_id)
{
  /*
   * Centering on a new post is likely to change which one we're hovering over.  Unexpand
   * the current post before scrolling, so the post doesn't flicker expanded in a new position
   * before being un-expanded by the mouseover event.
   */
  this.expand_post(null);

  this.center_on_post(post_id);

  /*
   * Now that we've re-centered, we need to expand the correct image.  Usually, we can just
   * wait for the mouseover event to fire, which will expand the element we're hovering over
   * after centering on the new post.  However, in some cases we won't actually change which
   * one we're hovering over, eg. if the mouse is over the edge of a landscape image, and
   * after scrolling the mouse is centered over the same image.  Explicitly figure out which
   * item we're hovering over and expand it.
   *
   * This doesn't work correctly in IE7; elementFromPoint is returning the wrong element.
   */
  var element = document.elementFromPoint(this.last_mouse_x, this.last_mouse_y);
  if(element)
  {
    var li = element.up(".post-thumb");
    if(li)
    {
      var post_id = li.post_id;
      this.expand_post(post_id);
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
  node.removeChild(node_to_remove);
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

    var thumb = this.create_thumb(this.post_ids[post_idx_to_populate]);
    node.insertBefore(thumb, null);
  }
  else
  {
    if(this.posts_populated[0] == 0)
      return false;
    --this.posts_populated[0];
    var post_idx_to_populate = this.posts_populated[0];
    var thumb = this.create_thumb(this.post_ids[post_idx_to_populate]);
    node.insertBefore(thumb, node.firstChild);
  }
  return true;
}

/* Fill the container so post_id is visible. */
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

  var thumb = this.create_thumb(this.post_ids[post_idx]);
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

/* Return the total width of all thumbs to the left or right of post_id, not
 * including post_id itself. */
ThumbnailView.prototype.get_width_adjacent_to_post = function(post_id, right)
{
  var post = $("p" + post_id);
  if(right)
  {
    var rightmost_node = post.parentNode.lastChild;
    if(rightmost_node == post)
      return 0;
    var right_edge = rightmost_node.offsetLeft + rightmost_node.offsetWidth;
    return right_edge - post.offsetLeft - post.offsetWidth;
  }
  else
  {
    return post.offsetLeft;
  }
}

/* Center the thumbnail strip on post_id.  If post_id isn't in the display, do nothing.
 * Fire viewer:need-more-thumbs if we're scrolling near the edge of the list. */
ThumbnailView.prototype.center_on_post = function(post_id)
{
  var post_idx = this.post_ids.indexOf(post_id);
  if(post_idx == -1)
    return; /* post_id isn't one of our posts */

  if(post_idx > this.post_ids.length*3/4)
  {
    /* We're coming near the end of the loaded posts, so load more. */
    document.fire("viewer:need-more-thumbs", { view: this });
  }

  this.centered_post_id = post_id;

  /* If we're not expanded, we can't figure out how to center it since we'll have no width.
   * Also, don't cause thumbnails to be loaded if we're hidden.  Just set centered_post_id,
   * and we'll come back here when we're displayed. */
  if(!this.thumb_container_shown)
    return;


  /* Clear the padding before calculating the new padding. */
  var node = this.container.down(".post-browser-posts");
  node.setStyle({marginLeft: 0});

  this.populate_post(post_idx);

  /* Make sure that we have enough posts populated around the one we're centering
   * on to fill the display.  If we have too many nodes, remove some. */
  for(var direction = 0; direction < 2; ++direction)
  {
    var right = !!direction;

    /* We need at least this.container.offsetWidth/2 in each direction.  Load a little more, to
     * reduce flicker. */
    var minimum_distance = this.container.offsetWidth*3/4;
    var maximum_distance = minimum_distance + 500;
    while(true)
    {
      var added = false;
      var width = this.get_width_adjacent_to_post(post_id, right);
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

  /* 
   * We have to jump some hoops to scroll the thumbs correctly.  We should be able to
   * set the container to overflow-x: hidden and just change scrollLeft to scroll the
   * contents.  Unfortunately, we also need overflow-y: visible to allow expanded thumbs
   * to draw outside of the container, and most browsers don't handle "overflow: hidden visible",
   * mysteriously changing it to "auto visible".
   *
   * Since the container is set to visible, we can't scroll it that way.  Instead, we'll change
   * the marginLeft of the <UL> itself to move the list around.  Setting a negative margin works
   * the way we want, causing the list to scroll to the left.
   */

  var thumb = $("p" + post_id);
  var img = thumb.down(".preview");

  /* We always center the thumb.  Don't clamp to the edge when we're near the first or last
   * item, so we always have empty space on the sides for expanded landscape thumbnails to
   * be visible. */
  var center_on_position = this.container.offsetWidth/2;

  var shift_pixels_right = center_on_position - img.width/2 - img.cumulative_offset_range_x(img.up("UL"));

  /* As of build 3516 (10.63), Opera is handling offsetLeft for elements inside fixed containers
   * incorrectly: they're affected by the scroll position, even though the nodes aren't.  This
   * is annoying to work around; let's just subtract out the error.  This will break if Opera fixes
   * this bug, in which case we can remove this and expect people to upgrade.  */
  if(window.opera)
    shift_pixels_right += document.documentElement.scrollLeft;

  node.setStyle({marginLeft: shift_pixels_right + "px"});
}

/* Preload thumbs on the boundary of what's actually displayed. */
ThumbnailView.prototype.preload_thumbs = function()
{
  var post_ids = [];
  for(var i = 0; i < 5; ++i)
  {
    var preload_post_idx = this.posts_populated[0] - i - 1;
    if(preload_post_idx >= 0)
      post_ids.push(this.post_ids[preload_post_idx]);

    var preload_post_idx = this.posts_populated[1] + i;
    if(preload_post_idx < this.post_ids.length)
      post_ids.push(this.post_ids[preload_post_idx]);
  }

  /* Remove any preloaded thumbs that are no longer in the preload list. */
  var to_remove = [];
  this.thumb_preloads.each(function(e) {
    var post_id = parseInt(e[0]);
    var element = e[1];
    if(post_ids.indexOf(post_id) != -1)
      return;
    to_remove.push(post_id);
  });

  for(var i = 0; i < to_remove.length; ++i)
  {
    var post_id = to_remove[i];
    var element = this.thumb_preloads.get(post_id);
    this.thumb_preloads.unset(post_id);
    this.thumb_preload_container.removeChild(element);
  }

  /* Add new preloads. */
  for(var i = 0; i < post_ids.length; ++i)
  {
    var post_id = post_ids[i];
    if(this.thumb_preloads.get(post_id) != null)
      continue;

    var post = Post.posts.get(post_id);
    var element = this.thumb_preload_container.preload(post.preview_url);
    this.thumb_preloads.set(post_id, element);
  }
}

ThumbnailView.prototype.expand_post = function(post_id)
{
  if(!this.thumb_container_shown)
    return;

  if(this.expanded_post_id != null)
  {
    var old_thumb = $("p" + this.expanded_post_id);
    if(old_thumb)
      old_thumb.removeClassName("expanded");
  }

  this.expanded_post_id = post_id;
  if(post_id == null)
    return;

  var thumb = $("p" + post_id);
  thumb.addClassName("expanded");
}

ThumbnailView.prototype.create_thumb = function(post_id)
{
  var post = Post.posts.get(post_id);

  var width = post.actual_preview_width;
  var height = post.actual_preview_height;
/*
  var block_size = [width, 200];
  var crop_left = 0;
*/
  /* This crops blocks that are too wide, but doesn't pad them if they're too
   * narrow, since that creates odd spacing. */
  var block_size = [200, 200];
  if(width < block_size[0])
    block_size[0] = width;
  var visible_width = block_size[0];
  if(width < visible_width)
    visible_width = width;
  var crop_left = (width - visible_width) / 2;

  var div =
    '<div class="inner" style="width: ${block_size_x}px; height: ${block_size_y}px;">' +
      '<a class="thumb" href="${target_url}">' +
        '<img src="${preview_url}" style="display: none; margin-left: -${crop_left}px;" alt="" class="${image_class}" width="${width}" height="${height}" onload="$(this).show();">'
      '</a>' +
    '</div>';
  div = div.subst({
    block_size_x: block_size[0],
    block_size_y: block_size[1],
    target_url: "/post/show/" + post.id,
    preview_url: post.preview_url,
    crop_left: crop_left,
    width: width,
    height: height,
    image_class: "preview"
  });
    
  var li_class = "post-thumb";
  li_class += " creator-id-" + post.creator_id;
  if(post.status == "flagged") li_class += " flagged";
  if(post.has_children) li_class += " has-children";
  if(post.parent_id) li_class += " has-parent";
  if(post.status == "pending") li_class += " pending";

  var item = createElement("li", li_class, div);

  item.className = li_class;
  item.id = "p" + post_id;
  item.post_id = post_id;

  // We need to specify a width on the <li>, since IE7 won't figure it out on its own.
  item.setStyle({width: block_size[0] + "px"});
  return item;
}

/* Handle clicks and doubleclicks on thumbnails.  These events are handled by
 * the container, so we don't need to put event handlers on every thumb. */
ThumbnailView.prototype.container_click_event = function(event)
{
  var li = event.target.up(".post-thumb");
  if(li == null)
    return;

  event.preventDefault();
  this.set_active_post(li.post_id);
}

ThumbnailView.prototype.container_dblclick_event = function(event)
{
  var li = event.target.up(".post-thumb");
  if(li == null)
    return;

  event.preventDefault();
  this.show_thumb_bar(false)
}

ThumbnailView.prototype.show_thumb_bar = function(shown)
{
  this.thumb_container_shown = shown;
  this.container.show(shown);

  /* If the centered post was changed while we were hidden, it wasn't applied by
   * center_on_post, so do it now. */
  if(shown)
    this.center_on_post(this.centered_post_id)
}

ThumbnailView.prototype.toggle_thumb_bar = function()
{
  this.show_thumb_bar(!this.thumb_container_shown);
}


/* Return the next or previous post, wrapping around if necessary. */
ThumbnailView.prototype.get_adjacent_post_id_wrapped = function(post_id, next)
{
  var idx = this.post_ids.indexOf(post_id);
  idx += next? +1:-1;
  idx = (idx + this.post_ids.length) % this.post_ids.length;
  return this.post_ids[idx];
}

ThumbnailView.prototype.displayed_image_finished_loading = function(success, post_id, event)
{
  /* If the image that just finished loading isn't actually the one being displayed,
   * ignore it. */
  if(this.view.displayed_post_id != post_id)
    return;

  /*
   * The image in the post we're displaying is finished loading.
   *
   * Preload the next and previous posts.  Normally, one or the other of these will
   * already be in cache.
   */
  var post_ids_to_preload = [];
  var adjacent_post_id = this.get_adjacent_post_id_wrapped(post_id, true);
  if(adjacent_post_id != null)
    post_ids_to_preload.push(adjacent_post_id);
  var adjacent_post_id = this.get_adjacent_post_id_wrapped(post_id, false);
  if(adjacent_post_id != null)
    post_ids_to_preload.push(adjacent_post_id);
  this.view.preload(post_ids_to_preload);
}

