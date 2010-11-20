ThumbnailView = function(container, post_ids, pool)
{
  this.container = container;
  this.post_ids = post_ids;
  this.focused_post_id = null;
  this.pool = pool;

  this.hashchange_event = this.hashchange_event.bindAsEventListener(this);
  this.thumbnail_click_event = this.thumbnail_click_event.bindAsEventListener(this);
  this.mouse_wheel_event = this.mouse_wheel_event.bindAsEventListener(this);

  this.container.observe("DOMMouseScroll", this.mouse_wheel_event);
  this.container.observe("mousewheel", this.mouse_wheel_event);

  Post.observe_finished_loading(this.displayed_image_finished_loading.bind(this));


  OnKey(65, { AlwaysAllowOpera: true, allowRepeat: true }, function(e) { this.scroll(true); }.bind(this));
  OnKey(83, { AlwaysAllowOpera: true, allowRepeat: true }, function(e) { this.scroll(false); }.bind(this));

  this.ignore_hash_changes_until = 0;
  Element.observe(window, "hashchange", this.hashchange_event);

  document.observe("mouseout", function(e) { if(e.relatedTarget != null) return; this.set_visibility_from_mouse_pos(0, 1000000); }.bindAsEventListener(this));
  
  this.document_mousemove_event = this.document_mousemove_event.bindAsEventListener(this);
  document.observe("mousemove", this.document_mousemove_event);

  for(var i = 0; i < post_ids.length; ++i)
  {
    var thumb = this.create_thumb(post_ids[i]);
    container.down(".post-browser-posts").appendChild(thumb);
  }

  var initial_post_id = this.get_current_post_id();

  this.focus_post(initial_post_id);
  pool_browser.set_post(initial_post_id);
}

ThumbnailView.prototype.hashchange_event = function(e)
{
  var new_post_id = this.get_current_post_id();

  /*
   * There's an annoying bug in FF: the hashchange event isn't delivered immediately
   * when the hash changes, but queued and sent later.  This causes ugly race conditions;
   * we can't tell whether hash changes are coming from the user requesting a state
   * change, or if they're from us updating the current--and now possibly out-of-date--state.
   * The effect of this is that quick changes to the active post can be lost, leaving us
   * on a different post than was requested.
   *
   * Work around this with a hack: after setting a new hash, ignore changes to the hash for
   * a little while.  The events are dispatched after we return from whatever event we're
   * handling.
   */
  if((new Date()).valueOf() < this.ignore_hash_changes_until)
    return;

  this.focus_post(new_post_id);
  pool_browser.set_post(new_post_id);
}

ThumbnailView.prototype.get_current_post_id = function()
{
  var hash = document.location.hash;
  if(!hash)
    return this.post_ids[0];
  hash = hash.substr(1);
  var post_id = parseInt(hash);
  if(this.post_id_idx(post_id) == -1)
    return this.post_ids[0];

  return post_id;
}

ThumbnailView.prototype.set_visibility_from_mouse_pos = function(x, y)
{
  var offset = this.container.cumulativeOffset();
  var fade_distance = 150.0;
  var box_top = offset.top;
  var box_bottom = 350;

  var a;
  if(y < box_top)
  {
    var d = box_top - y;
    a = (fade_distance-d)/fade_distance;
  }
  else if(y >= box_bottom)
  {
    var d = y - box_bottom;
    a = (fade_distance-d)/fade_distance;
  }
  else
  {
    a = 1;
  }

  if(a < 0) a = 0;
  if(a > 1) a = 1;

  this.container.setStyle({top: -(1-a)*box_bottom + "px"});

}

ThumbnailView.prototype.document_mousemove_event = function(e) {
  this.set_visibility_from_mouse_pos(e.pointerX(), e.pointerY() - document.documentElement.scrollTop);
}

ThumbnailView.prototype.mouse_wheel_event = function(event)
{
  event.preventDefault();

  var val;
  if(event.wheelDelta)
  {
    val = event.wheelDelta;
    if (window.opera)
      val = -val;
  } else if (event.detail) {
    val = -event.detail;
  }

  this.scroll(val >= 0);
}

ThumbnailView.prototype.post_id_idx = function(post_id)
{
  for(var i = 0; i < this.post_ids.length; ++i)
  {
    if(this.post_ids[i] == post_id)
      return i;
  }
  return -1;
}

ThumbnailView.prototype.scroll = function(up)
{
  var current_post_id = this.focused_post_id;
  if(current_post_id == null)
    current_post_id = this.post_ids[0];

  var current_idx = this.post_id_idx(current_post_id);
  var new_idx = current_idx + (up? -1:+1);

  /* Wrap the new index. */
  // XXX: only notice() if we're not expanded
  if(new_idx < 0)
  {
    notice("Continued from the end");
    new_idx = this.post_ids.length - 1;
  }
  else if(new_idx >= this.post_ids.length)
  {
    notice("Starting over from the beginning");
    new_idx = 0;
  }
  new_idx = (new_idx + this.post_ids.length) % this.post_ids.length;

  var new_post_id = this.post_ids[new_idx];
  this.focus_post(new_post_id);

  /* Ask the pool browser to load the new post, with a delay in case we're
   * scrolling quickly. */
  pool_browser.lazily_load(new_post_id);
}

ThumbnailView.prototype.focus_post = function(post_id)
{
  if(post_id == this.focused_post_id)
    return;

  if(this.focused_post_id != null)
  {
    var old_thumb = $("p" + this.focused_post_id);
    old_thumb.down(".inner").setStyle({overflow: "hidden"});
    old_thumb.setStyle({zIndex: 0});
    this.focused_post_id = null;
  }

  /* 
   * We have to jump some hoops to scroll the thumbs correctly.  We should be able to
   * set the container to overflow-x: hidden and just change scrollLeft to scroll the
   * contents.  Unfortunately, we also need overflow-y: visible to allow expanded thumbs
   * to draw outside of the container, and most browsers don't handle "overflow: hidden visible",
   * mysteriously changing it to "auto visible".
   *
   * Since the container is set to visible, we can't scroll it that way.  Instead, we've
   * inserted a padding entry at the beginning.  To scroll the whole list, we'll change
   * its marginLeft.  Setting a negative margin works the way we want, causing the list to
   * scroll to the left.
   */
  var padding = this.container.down(".post-padding");

  /* Clear the padding before calculating the new padding. */
  padding.setStyle({marginLeft: 0});

  var thumb = $("p" + post_id);
  var img = thumb.down(".preview");

  var window_left = document.documentElement.scrollLeft;
  var window_top = document.documentElement.scrollTop;

  /* We always center the thumb.  Don't clamp to the edge when we're near the first or last
   * item, so we always have empty space on the sides for expanded landscape thumbnails to
   * be visible. */
  var shift_pixels_right = this.container.offsetWidth/2 - img.width/2 - img.cumulative_offset_range_x(img.up("UL"));

  /* As of build 3516 (10.63), Opera is handling offsetLeft for elements inside fixed containers
   * incorrectly: they're affected by the scroll position, even though the nodes aren't.  This
   * is annoying to work around; let's just subtract out the error.  This will break if Opera fixes
   * this bug, in which case we can remove this and expect people to upgrade.  */
  if(window.opera)
    shift_pixels_right += document.documentElement.scrollLeft;

  padding.setStyle({marginLeft: shift_pixels_right + "px"});
  thumb.down(".inner").setStyle({overflow: "visible"});
  thumb.setStyle({zIndex: 30});

  /* If we're browsing a pool, set the title. */
  if(this.pool)
  {
    var post = Post.posts.get(post_id);
    title = this.pool.name.replace(/_/g, " ");

    if(post.pool_post)
    {
      var sequence = post.pool_post.sequence;
      title += " ";
      if(sequence.match(/^[0-9]/))
        title += "#";
      title += sequence;
    }

    document.title = title;
  }

  this.ignore_hash_changes_until = (new Date()).valueOf() + 100;
  document.location.hash = post_id;
  this.focused_post_id = post_id;
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
    '<div class="inner" style="overflow: hidden; width: ${block_size_x}px; height: ${block_size_y}px;">' + 
      '<a class="thumb" href="${target_url}">' +
        '<img src="${preview_url}" style="margin-left: -${crop_left}px;" alt="" class="${image_class}" width="${width}" height="${height}">'
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
  var li_class = "";
  li_class += " creator-id-" + post.creator_id;
  if(post.status == "flagged") li_class += " flagged";
  if(post.has_children) li_class += " has-children";
  if(post.parent_id) li_class += " has-parent";
  if(post.status == "pending") li_class += " pending";

  var item = createElement("li", li_class, div);
  item.id = "p" + post_id;

  item.post_id = post_id;

  // We need to specify a width on the <li>, since IE7 won't figure it out on its own.
  item.setStyle({width: block_size[0] + "px"});

  item.down("A.thumb").observe("click", this.thumbnail_click_event);
  return item;
}

ThumbnailView.prototype.thumbnail_click_event = function(event)
{
    event.preventDefault();
    var li = event.target.up("LI");
    this.focus_post(li.post_id);
    pool_browser.set_post(li.post_id);
}

/* Return the next or previous post, wrapping around if necessary. */
ThumbnailView.prototype.get_adjacent_post_id_wrapped = function(post_id, next)
{
  var idx = this.post_id_idx(post_id);
  idx += next? +1:-1;
  idx = (idx + this.post_ids.length) % this.post_ids.length;
  return this.post_ids[idx];
}

ThumbnailView.prototype.displayed_image_finished_loading = function(success, post_id, event)
{
  /*
   * The image in the post we're displaying is finished loading.
   *
   * Preload the next and previous posts.  Normally, one or the other of these will
   * already be in cache.
   *
   * XXX: doesn't always make sense: the browser may be getting ready to switch to something else
   */
  // var post_id = this.displayed_post_id;
  var post_ids_to_preload = [];
  var adjacent_post_id = this.get_adjacent_post_id_wrapped(post_id, true);
  if(adjacent_post_id != null)
    post_ids_to_preload.push(adjacent_post_id);
  var adjacent_post_id = this.get_adjacent_post_id_wrapped(post_id, false);
  if(adjacent_post_id != null)
    post_ids_to_preload.push(adjacent_post_id);
  pool_browser.preload(post_ids_to_preload);
}

