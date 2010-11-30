PostLoader = function()
{
  document.on("viewer:need-more-thumbs", this.need_more_post_data.bindAsEventListener(this));

  this.hashchange_tags = this.hashchange_tags.bind(this);
  UrlHash.observe("tags", this.hashchange_tags);

  this.cached_posts = new Hash();
  this.cached_pools = new Hash();

  this.load(false);
}

PostLoader.prototype.need_more_post_data = function()
{
  /* We'll receive this message often once we're close to needing more posts.  Only
   * start loading more data the first time. */
  if(this.loaded_extended_results)
    return;

  this.load(true, false);
}


PostLoader.prototype.server_load_pool = function()
{
  if(this.result.pool_id == null)
    return;

  if(!this.result.disable_cache)
  {
    var pool = this.cached_pools.get(this.result.pool_id);
    if(pool)
    {
      this.result.pool = pool;
      this.request_finished();
      return;
    }
  }

  new Ajax.Request("/pool/show.json", {
    parameters: { id: this.result.pool_id },
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
      this.cached_pools.set(this.result.pool_id, this.result.pool);
    }.bind(this)
  });
}

PostLoader.prototype.server_load_posts = function()
{
  var tags = this.result.tags;
  var search = tags + " limit:" + this.result.post_limit;

  if(!this.result.disable_cache)
  {
    var results = this.cached_posts.get(search);
    if(results)
    {
      this.result.posts = results;

      /* Don't Post.register the results when serving out of cache.  They're already
       * registered, and the data in the post registry may be more current than the
       * cached search results. */
      this.request_finished();
      return;
    }
  }

  new Ajax.Request("/post/index.json", {
    parameters: {
      tags: search,
      api_version: 2,
      filter: 1,
      include_tags: 1
    },
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
    
      var posts = resp.responseJSON.posts;
      this.result.posts = posts;

      Post.register_tags(resp.responseJSON.tags);
      for(var i = 0; i < posts.length; ++i)
        Post.register(posts[i]);

      this.cached_posts.set(search, this.result.posts);
    }.bind(this),

    onFailure: function(resp) {
      notice("Error " + resp.status + " loading posts");
      this.result.error = true;
    }.bind(this)
  });
}

PostLoader.prototype.request_finished = function()
{
  if(this.current_ajax_requests.length)
    return;

  /* Event handlers for the events we fire below might make requests back to us.  Save and
   * clear this.result before firing the events, so that behaves properly. */
  var result = this.result;
  this.result = null;

  /* If server_load_posts hit an error, it already displayed it; stop. */
  if(result.error != null)
    return;

  /* If we have no search tags (result.tags == null, result.posts == null), then we're just
   * displaying a post with no search, eg. "/post/browse#12345".  We'll still fire off the
   * same code path to make the post display in the view. */
  var new_post_ids = [];
  if(result.posts != null)
  {
    for(var i = 0; i < result.posts.length; ++i)
      new_post_ids.push(result.posts[i].id);
  }

  document.fire("viewer:displayed-pool-changed", { pool: result.pool });
  document.fire("viewer:searched-tags-changed", { tags: result.tags });

  /* Tell the thumbnail viewer whether it should allow scrolling over the left side. */
  var can_be_extended_further = true;

  /* If we're reading from a pool, we requested a large block already. */
  if(result.pool)
    can_be_extended_further = false;

  /* If we're already extending, don't extend further. */
  if(result.extending)
    can_be_extended_further = false;

  /* If we received fewer results than we requested we're at the end of the results,
   * so don't waste time requesting more. */
  if(new_post_ids.length < result.post_limit)
  {
    debug.log("Received posts fewer than requested (" + new_post_ids.length + " < " + result.post_limit + "), clamping");
    can_be_extended_further = false;
  }

  document.fire("viewer:loaded-posts", {
    tags: result.tags, /* this will be null if no search was actually performed (eg. URL with a post-id and no tags) */
    post_ids: new_post_ids,
    pool: result.pool,
    extending: result.extending,
    can_be_extended_further: can_be_extended_further
  });
}

/* If extending is true, load a larger set of posts. */
PostLoader.prototype.load = function(extending, disable_cache)
{
  /* If neither a search nor a post-id is specified, set a default search. */
  if(!extending && UrlHash.get("tags") == null && UrlHash.get("post-id") == null)
  {
    UrlHash.set({tags: ""});

    /* We'll receive another hashchange message for setting "tags".  Don't load now or we'll
     * end up loading twice. */
    return;
  }

  debug.log("PostLoader.load(" + extending + ", " + disable_cache + ")");

  this.loaded_extended_results = extending;

  /* Discard any running AJAX requests. */
  this.current_ajax_requests = [];

  this.result = {};
  this.result.tags = UrlHash.get("tags");
  this.result.disable_cache = disable_cache;
  this.result.extending = extending;

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
  this.result.pool_id = pool_id;

  this.result.extending = extending;

  /* Load the posts to display.  If we're loading a pool, load all posts (up to 1000);
   * otherwise set a limit. */
  var limit = extending? 1000:100;
  if(pool_id != null)
    limit = 1000;
  this.result.post_limit = limit;


  /* Make sure that request_finished doesn't consider this request complete until we've
   * actually started every request. */
  this.current_ajax_requests.push(null);

  this.server_load_pool();
  this.server_load_posts();

  this.current_ajax_requests = this.current_ajax_requests.without(null);
  this.request_finished();
}

PostLoader.prototype.hashchange_tags = function()
{
  this.load(false, false);
}

 
