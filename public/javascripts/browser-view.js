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

BrowserView = function()
{
  /* The post that we currently want to display.  This will be either one of the
   * current html_preloads, or be the displayed_post_id. */
  this.wanted_post_id = null;

  /* The post that's currently actually being displayed. */
  this.displayed_post_id = null;

  this.cache_session_id = (new Date()).valueOf();
  this.post_node_cache = new Hash;
  this.post_html_cache = new Hash;
  this.html_preloads = new Hash;

//  this.set_post(this.get_current_post_id());

  this.error = "";
  this.log_data = "";
  this.set_debug();
}

BrowserView.prototype.log = function(s)
{
  this.log_data += " " + s;
  var max_length = 200;
  if(this.log_data.length > max_length)
    this.log_data = this.log_data.substr(this.log_data.length-max_length, max_length);
}

BrowserView.prototype.set_debug = function()
{
  var s = "wanted: " + this.wanted_post_id + ", displayed: " + this.displayed_post_id;
  var preload_keys = this.html_preloads.keys();
  if(preload_keys.length > 0)
    s += ", loading " + preload_keys;
  if(this.lazy_load_timer)
    s += ", lazy load pending";
  if(this.error != "")
    s += ", error: " + this.error;
  s += " -- " + this.log_data;

  $("debug").update(s);
  this.debug_timer = window.setTimeout(this.set_debug.bind(this), 100);
}

/* If post_id isn't cached and isn't already being loaded, start loading it. */
BrowserView.prototype.load_post_html = function(post_id)
{
  /* If the post's node is cached, then there's never any reason to load its HTML again. */
  if(this.post_node_cache.get(post_id))
    return;

  var data = this.post_html_cache.get(post_id);
  if(data != null)
  {
    /* This post's HTML is already loaded. */
    if(this.wanted_post_id == post_id)
    {
      this.post_html_cache.unset(post_id);
      this.set_post_content(data, post_id);
    }
    return;
  }
  
  if(this.html_preloads.get(post_id) != null)
  {
    /* This post is already being loaded. */
    return;
  }

  var url = this.get_url_for_post_page(post_id);
  var request = new Ajax.Request(url, {
    method: "get",
    evalJSON: false,
    evalJS: false,
    parameters: null,
    onComplete: function(resp)
    {
      /* Always remove the request from html_preloads, regardless of whether it succeeded
       * or not. */
      this.html_preloads.unset(post_id);
    }.bind(this),

    onSuccess: function(resp)
    {
      resp = resp.responseText;

      /* If this is the post that we currently want displayed, switch to it.
       * There's no need to cache the text in post_html_cache in this case,
       * since we're already converting it to an element. */
      if(post_id == this.wanted_post_id)
      {
        this.set_post_content(resp, post_id);
        return;
      }

      /* Otherwise, just cache the data for later. */
      this.post_html_cache.set(post_id, resp);
    }.bind(this),

    onFailure: function(resp)
    {
      if(this.wanted_post_id == post_id)
      {
        /* The post the user wants to see failed to load. */
        notice("Error "  + resp.status + " loading post");
      }
    }.bind(this)
  });

  this.html_preloads.set(post_id, request);
}

/* Begin preloading the HTML and images for the given post IDs. */
BrowserView.prototype.preload = function(post_ids)
{
  var new_preload_container = Preload.create_preload_container();
  for(var i = 0; i < post_ids.length; ++i)
  {
    var post_id = post_ids[i];

    this.load_post_html(post_id);

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

BrowserView.prototype.clear_container = function()
{
  var content = $("post-content");
  var old_container = content.down(".post-content-container");
  if(!old_container)
    return;

  /* We're no longer displaying the post, but we'll keep a reference to the container
   * in post_node_cache.  Clear the image source attribute, to help hint the browser that
   * we don't need to keep the image around.  We'll restore it if we display the post
   * again. */
  var img = old_container.down("#image");
  if(img)
  {
    img.saved_src = img.src;
    img.src = "about:blank";
  }
  content.removeChild(old_container);
}

BrowserView.prototype.set_post_content = function(data, post_id)
{
  /* Clear the previous post, if any. */
  this.clear_container();

  this.displayed_post_id = post_id;

  var content = $("post-content");

  if(typeof(data) == typeof "")
  {
    /* The argument is a string, so it's a new, raw block of HTML.  We need to create
     * its node. */
    var post_content_container = $(document.createElement("DIV"));
    post_content_container.className = "post-content-container";

    content.appendChild(post_content_container);

    /* This is like post_content_container.update(data), but we don't defer scripts, since
     * that breaks things (eg. resized_notice gets moved around later, after we've already
     * aligned the viewport). */
    post_content_container.innerHTML = data.stripScripts();
    data.evalScripts(data);

    InitTextAreas();

    this.post_node_cache.set(post_id, post_content_container);
  }
  else
  {
    /* The argument is the node that we created previously.  Just insert it. */
    var img = data.down(".image");
    if(img)
      img.src = img.saved_src;
    
    content.appendChild(data);
  }

  Post.scale_and_fit_image();

  Post.init_post_show(post_id);
}

BrowserView.prototype.get_url_for_post_page = function(post_id)
{
  return "/post/show/" + post_id + "?browser=1&cache=" + this.cache_session_id;
}

BrowserView.prototype.set_post = function(post_id)
{
  /* If there was a lazy load pending, cancel it. */
  this.cancel_lazily_load();

  this.wanted_post_id = post_id;

  /* If the post is already displayed, then we don't need to do anything else. */
  if(post_id == this.displayed_post_id)
    return;

  var post_content_container = this.post_node_cache.get(post_id);
  if(post_content_container)
  {
    this.set_post_content(post_content_container, post_id);
    return;
  }

  /* We don't have the node cached.  Open the page from HTML cache or start
   * loading the page as necessary. */
  this.load_post_html(post_id);
}

BrowserView.prototype.is_post_id_cached = function(post_id)
{
  return this.post_node_cache.get(post_id) != null || this.post_html_cache.get(post_id) != null;
}

/* If post_id is already cached, set it and return true.  Otherwise, return false and do nothing. */
BrowserView.prototype.set_post_if_cached = function(post_id)
{
  if(!this.is_post_id_cached(post_id))
    return false;
  this.set_post(post_id);
  return true;
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

//  if(this.set_post_if_cached(post_id))
//    return;
  var ms = this.is_post_id_cached(post_id)? 50:500;

  /* Once lazily_load is called with a new post, we should consistently stay on the current
   * post or change to the new post.  We shouldn't change to a post that was previously
   * requested by lazily_load (due to a background request completing).  Mark whatever post
   * we're currently on as the one we want, until we're able to switch to the new one. */
  this.wanted_post_id = this.displayed_post_id;

  this.lazy_load_post_id = post_id;
  this.lazy_load_timer = window.setTimeout(function() {
    if(this.lazy_load_post_id != post_id)
      this.error = "huh";
    this.lazy_load_timer = null;
    this.set_post(post_id);
  }.bind(this), ms);
}

