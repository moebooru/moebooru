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
 * - We don't depend on browser caching for HTML.  That would require us to expire a
 *   page when we switch away from it if we've made any changes (eg. voting), so we
 *   don't pull an out-of-date page next time.  This is slower, and would require us
 *   to be careful about expiring the cache.
 *
 * use browser cache for text cache and just Preload.preload_raw
 *
 * what happens to the browser cache when we expire the node cache?
 * should be expired
 * having an sid would only let us expire everything
 *
 */
PoolBrowser = function(pool, pool_posts)
{
  this.pool = pool;
  this.pool_id = pool.id;
  this.pool_posts = pool_posts;
  this.current_post_id = null;
  this.html_cache = new Hash;
  this.post_lru = new Array;
  this.cache_session_id = (new Date()).valueOf();
  this.post_id_version = new Hash;

  Post.observe_finished_loading(this.displayed_image_finished_loading.bind(this));

  this.set_post(this.get_current_post_id());

  OnKey(65, { AlwaysAllowOpera: true }, function(e) { this.move(false); }.bind(this));
  OnKey(83, { AlwaysAllowOpera: true }, function(e) { this.move(true); }.bind(this));

  Element.observe(window, "hashchange", function(e) {
    this.set_post(this.get_current_post_id(), this.pool_id);
  }.bind(this));
}

PoolBrowser.prototype.get_first_post_id = function()
{
  return this.pool_posts[0].post_id;
}

PoolBrowser.prototype.get_current_post_id = function()
{
  var hash = document.location.hash;
  if(!hash)
    return this.get_first_post_id();
  hash = hash.substr(1);

  return parseInt(hash);
}

PoolBrowser.prototype.get_post_id_version = function(post_id)
{
  var version = this.post_id_version.get(post_id);
  if(version == null)
    return 0;
  return version;
}

PoolBrowser.prototype.bump_post_id_version = function(post_id)
{
  var version = this.get_post_id_version(post_id);
  ++version;
  this.post_id_version.set(post_id, version);
}

PoolBrowser.prototype.find_post_idx_in_pool = function(post_id)
{
  for(var i = 0; i < this.pool_posts.length; ++i)
  {
    if(this.pool_posts[i].post_id == post_id)
      return i;
  }
  return -1;
}

PoolBrowser.prototype.find_post_in_pool = function(post_id)
{
  var idx = this.find_post_idx_in_pool(post_id);
  if(idx == -1)
    return null;
  return this.pool_posts[idx];
}

/* Move post_id to the top of the LRU. */
PoolBrowser.prototype.touch_lru = function(post_id)
{
  this.post_lru = this.post_lru.without(post_id);
  this.post_lru.unshift(post_id);
}

PoolBrowser.prototype.cache_cull = function()
{
  var max_cached_items = 3;

  /* Keep the max_cached_items most recently-used items. */
  var ids_to_keep = this.post_lru.slice(0, max_cached_items);

  /* Make a list of cache entries to discard. */
  var ids_to_purge = new Array;
  this.html_cache.each(function(e) {
    var post_id = parseInt(e[0]);
    if(ids_to_keep.indexOf(post_id) != -1)
      return;
    ids_to_purge.push(post_id);
  });

  ids_to_purge.each(function(post_id) {
    this.html_cache.unset(post_id);

    /* We're expiring the post from our cache, and we'll request it from the server
     * again next time.  Bump the cache version, to make sure any changes we've made
     * to the post while we had it cached are reloaded. */
    this.bump_post_id_version(post_id);
  }.bind(this));
}


PoolBrowser.prototype.displayed_image_finished_loading = function(success, event)
{
  /*
   * The image in the post we're displaying is finished loading.  
   *
   * Preload the next and previous posts.  Normally, one or the other of these will
   * already be in cache.
   */
  var post_id = this.current_post_id;
  var pool_post = this.find_post_in_pool(post_id);
  var post_ids_to_preload = [];
  var adjacent_pool_post = this.get_adjacent_post_id_wrapped(pool_post, true);
  if(adjacent_pool_post != null)
    post_ids_to_preload.push(adjacent_pool_post);
  var adjacent_pool_post = this.get_adjacent_post_id_wrapped(pool_post, false);
  if(adjacent_pool_post != null)
    post_ids_to_preload.push(adjacent_pool_post);
  this.preload(post_ids_to_preload);
},

/* Begin preloading the HTML and images for the given post IDs. */
PoolBrowser.prototype.preload = function(post_ids)
{
  var new_preload_container = Preload.create_preload_container();
  for(var i = 0; i < post_ids.length; ++i)
  {
    var post_id = post_ids[i];

    var html_url = this.get_url_for_post_page(post_id);
    Preload.create_raw_preload(html_url);

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

PoolBrowser.prototype.set_post_content = function(data, post_id)
{
  var content = $("post-content");
  var old_container = content.down(".post-content-container");
  if(old_container)
    content.removeChild(old_container);

  var post_content_container = document.createElement("DIV");
  post_content_container.className = "post-content-container";
  content.appendChild(post_content_container);
  post_content_container.update(data);
  InitTextAreas();

  this.html_cache.set(post_id, post_content_container);

  this.touch_lru(post_id);
  this.cache_cull();
}

/* The displayed post has changed.  Update the rest of the display around it. */
PoolBrowser.prototype.current_post_changed = function(post_id)
{
  document.location.hash = post_id;

  var idx = this.find_post_idx_in_pool(post_id);
  var title = "";
  title = this.pool.name.replace(/_/g, " ");
  if(idx != -1)
  {
    var sequence = this.pool_posts[idx].sequence;
    title += " ";
    if(sequence.match(/^[0-9]/))
      title += "#";
    title += sequence;
  }

  document.title = title;
}

PoolBrowser.prototype.get_url_for_post_page = function(post_id)
{
  var cache_id = this.cache_session_id + "-" + post_id + "-" + this.get_post_id_version(post_id);
  var url = "/post/show/" + post_id + "?pool_id=" + this.pool_id + "&cache=" + cache_id;
  return url;
}

PoolBrowser.prototype.set_post = function(post_id)
{
  /* If the post isn't in the pool, pick a default. */
  if(this.find_post_in_pool(post_id) == null)
    post_id = this.get_first_post_id();

  if(this.current_post_id == post_id)
    return;
  this.current_post_id = post_id;

  var post_content_container = this.html_cache.get(post_id);
  if(post_content_container)
  {
    var content = $("post-content");
    var old_container = content.down(".post-content-container");
    if(old_container)
      content.removeChild(old_container);

    content.appendChild(post_content_container);
    this.current_post_changed(post_id);
    this.touch_lru(post_id);
    return;
  }

  var url = this.get_url_for_post_page(post_id);
  new Ajax.Request(url, {
    method: "get",
    evalJSON: false,
    evalJS: false,
    parameters: null,
    onSuccess: function(resp)
    {
      resp = resp.responseText;
      this.set_post_content(resp, post_id);
      this.current_post_changed(post_id);
    }.bind(this)
  });
}

/* If first is true, return the first pool_post in the pool, otherwise return the last pool_post. */
PoolBrowser.prototype.get_boundary_pool_post = function(first)
{
  if(first)
    return this.pool_posts[0];
  else
    return this.pool_posts[this.pool_posts.length-1];
}

/* If next is true, return the post after the given pool_post, otherwise return
 * the post before it. */
PoolBrowser.prototype.get_adjacent_post_id = function(pool_post, next)
{
  if(next)
    return pool_post.next_post_id;
  else
    return pool_post.prev_post_id;
}

/* Return the next or previous post, wrapping around if necessary. */
PoolBrowser.prototype.get_adjacent_post_id_wrapped = function(pool_post, next)
{
  var adjacent_pool_post_id = this.get_adjacent_post_id(pool_post, next);
  if(adjacent_pool_post_id != null)
    return adjacent_pool_post_id;
  return this.get_boundary_pool_post(next).post_id;
}

/* Change to the next or previous post in the pool. */
PoolBrowser.prototype.move = function(next)
{
  var pool_post = this.find_post_in_pool(this.get_current_post_id());
  var key = next? "next_post_id":"prev_post_id";
  var new_post_id = this.get_adjacent_post_id(pool_post, next); //pool_post[key];
  if(new_post_id == null)
  {
    if(next)
      notice("Starting over from the beginning");
    else
      notice("Continued from the end");
    new_post_id = this.get_boundary_pool_post(next).post_id;
  }

  this.set_post(new_post_id, this.pool_id);
}

