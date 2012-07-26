var _preload_image_pool = null;

PreloadContainer = function()
{
  /* Initialize the pool the first time we make a container, since we may not
   * have ImgPoolHandler when the file is loaded. */
  if(_preload_image_pool == null)
      _preload_image_pool = new ImgPoolHandler();

  this.container = $(document.createElement("div"));
  this.container.style.display = "none";
  document.body.appendChild(this.container);

  this.active_preloads = 0;

  this.on_image_complete_event = this.on_image_complete_event.bindAsEventListener(this);
}

PreloadContainer.prototype.cancel_preload = function(img)
{
  img.stopObserving();
  this.container.removeChild(img);
  _preload_image_pool.release(img);
  if(img.active)
    --this.active_preloads;
}

PreloadContainer.prototype.preload = function(url)
{
  ++this.active_preloads;

  var imgTag = _preload_image_pool.get();
  imgTag.observe("load", this.on_image_complete_event);
  imgTag.observe("error", this.on_image_complete_event);
  imgTag.src = url;
  imgTag.active = true;

  this.container.appendChild(imgTag);
  return imgTag;
}

/* Return an array of all preloads. */
PreloadContainer.prototype.get_all = function()
{
  return this.container.childElements();
}

PreloadContainer.prototype.destroy = function()
{
  this.get_all().each(function(img) {
    this.cancel_preload(img);
  }.bind(this));

  document.body.removeChild(this.container);
}

PreloadContainer.prototype.on_image_complete_event = function(event)
{
  --this.active_preloads;
  event.target.active = false;
}


Preload = {
  /*
   * Thumbnail preloading.
   *
   * After the main document (all of the thumbs you can actually see) finishes
   * loading, start loading thumbs from the surrounding pages.
   *
   * We don't use <link rel="prefetch"> for this:
   *  - Prefetch is broken in FF 3, see <https://bugzilla.mozilla.org/show_bug.cgi?id=442584>.
   *  - Prefetch is very slow; it uses only one connection and doesn't seem to pipeline
   *  at all.  It'll often not finish loading a page of thumbs before the user finishes
   *  scanning the previous page.  The "slow, background" design of FF's prefetching
   *  needs some knobs to tell it whether the prefetching should be slow or aggressive.
   *  - Prefetch turns itself off if you're downloading anything.  This makes sense if
   *  it's prefetching large data (if we prefetched sample images, we'd want that), but
   *  it makes no sense for downloading 300k of thumbnails.  Again, this should be
   *  tunable, eg. <link rel="prefetch" mode="active">.
   *
   * This also works in browsers other than FF.
   */
  preload_list: [],
  preload_container: null,
  preload_raw_urls: [],
  preload_started: false,
  onload_event_initialized: false,

  get_default_preload_container: function()
  {
    if(!this.preload_container)
      this.preload_container = new PreloadContainer();

    return this.preload_container;
  },
  init: function()
  {
    if(this.onload_event_initialized)
      return;

    this.onload_event_initialized = true;
    Event.observe(window, "load", function() { Preload.preload_started = true; Preload.start_preload(); } );
  },

  /* Preload the given URL once window.load has fired. */
  preload: function(url)
  {
    var container = this.get_default_preload_container();

    Preload.init();
    Preload.preload_list.push([url, container]);
    Preload.start_preload();
  },

  /* Load the given URL with an AJAX request.  This is used to load things that aren't
   * images. */
  preload_raw: function(url)
  {
    Preload.init();
    Preload.preload_raw_urls.push(url);
    Preload.start_preload();
  },

  create_raw_preload: function(url)
  {
    return new Ajax.Request(url, {
      method: "get",
      evalJSON: false,
      evalJS: false,
      parameters: null
    });
  },
  start_preload: function()
  {
    if(!Preload.preload_started)
      return;

    for(var i=0; i < Preload.preload_list.length; ++i)
    {
      var preload = Preload.preload_list[i];
      var container = preload[1];
      container.preload(preload[0]);
    }
    Preload.preload_list.length = [];

    for(var i=0; i < Preload.preload_raw_urls.length; ++i)
    {
      var url = Preload.preload_raw_urls[i];
      Preload.create_raw_preload(url);
    }
    Preload.preload_raw_urls = [];
  }
}
