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
  preload: function(url)
  {
    if(!this.preload_container)
    {
      this.preload_container = document.createElement("div");
      this.preload_container.style.display = "none";
      document.body.appendChild(this.preload_container);
      Event.observe(window, "load", function() { Preload.start_preload(); } );
    }

    Preload.preload_list.push(url);
  },

  start_preload: function()
  {
    var preload = this.preload_container;
    for(var i=0; i < Preload.preload_list.length; ++i)
    {
      var imgTag = document.createElement("img");
      imgTag.src = Preload.preload_list[i];
      preload.appendChild(imgTag);
    }
  }
}
