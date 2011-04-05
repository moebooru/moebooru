var PostUploadForm = function(form, progress)
{
  var XHRLevel2 = "XMLHttpRequest" in window && (new XMLHttpRequest().upload != null);
  var SupportsFormData = "FormData" in window;
  if(!XHRLevel2 || !SupportsFormData)
    return;
  
  this.form_element = form;
  this.cancel_element = this.form_element.down(".cancel");

  this.progress = progress;
  this.document_title = document.documentElement.down("TITLE");
  this.document_title_orig = this.document_title.textContent;
  this.current_request = null;
  this.form_element.on("submit", this.form_submit_event.bindAsEventListener(this));
  this.cancel_element.on("click", this.click_cancel.bindAsEventListener(this));

  var keypress_event_name = window.opera || Prototype.Browser.Gecko? "keypress":"keydown";
  document.on(keypress_event_name, this.document_keydown_event.bindAsEventListener(this));
}

PostUploadForm.prototype.set_progress = function(f)
{
  var percent = f * 100;
  this.progress.down(".upload-progress-bar-fill").style.width = percent + "%";
  this.document_title.textContent = this.document_title_orig + " (" + percent.toFixed(0) + "%)";
}

PostUploadForm.prototype.request_starting = function()
{
  this.form_element.down(".submit").hide();
  this.cancel_element.show();
  this.progress.show();
  document.documentElement.addClassName("progress");
}

PostUploadForm.prototype.request_ending = function()
{
  this.form_element.down(".submit").show();
  this.cancel_element.hide();
  this.progress.hide();
  this.document_title.textContent = this.document_title_orig;
  document.documentElement.removeClassName("progress");
}

PostUploadForm.prototype.document_keydown_event = function(e)
{
  var key = e.charCode;
  if(!key)
    key = e.keyCode; /* Opera */
  if(key != Event.KEY_ESC)
    return;
  this.cancel();
}

PostUploadForm.prototype.click_cancel = function(e)
{
  e.stop();
  this.cancel();
}


PostUploadForm.prototype.form_submit_event = function(e)
{
  /* This submit may have been stopped by User.run_login_onsubmit. */
  if(e.stopped)
    return;

  if(this.current_request != null)
    return;

  $("post-exists").hide();
  $("post-upload-error").hide();

  /* If the files attribute isn't supported, or we have no file (source upload), use regular
   * form submission. */
  var post_file = $("post_file");
  if(post_file.files == null || post_file.files.length == 0)
    return;

  e.stop();

  this.set_progress(0);
  this.request_starting();

  var form_data = new FormData(this.form_element);

  var onprogress = function(e)
  {
    var done = e.loaded;
    var total = e.total;
    this.set_progress(total? (done/total):1);
  }.bind(this);

  this.current_request = new Ajax.Request("/post/create.json", {
    contentType: null,
    method: "post",
    postBody: form_data,
    onCreate: function(resp)
    {
      var xhr = resp.request.transport;
      xhr.upload.onprogress = onprogress;
    },

    onComplete: function(resp)
    {
      this.current_request = null;
      this.request_ending();

      var json = resp.responseJSON;
      if(!json)
        return;

      if(!json.success)
      {
        if(json.location)
        {
          var a = $("post-exists-link");
          a.setTextContent("post #" + json.post_id);
          a.href = json.location;
          $("post-exists").show();
          return;
        }

        $("post-upload-error").setTextContent(json.reason);
        $("post-upload-error").show();

        return;
      }

      /* If a post/similar link was given and similar results exists, go to them.  Otherwise,
       * go to the new post. */
      var target = json.location;
      if(json.similar_location && json.has_similar_hits)
        target = json.similar_location;
      window.location.href = target;
    }.bind(this)
  });
}

/* Cancel the running request, if any. */
PostUploadForm.prototype.cancel = function()
{
  if(this.current_request == null)
    return;

  /* Don't clear this.current_request; it'll be done by the onComplete callback. */
  this.current_request.transport.abort();
}

/*
 * When file_field is changed to an image, run an image search and put a summary in
 * results.
 */
UploadSimilarSearch = function(file_field, results)
{
  if(!ThumbnailUserImage)
    return;

  this.file_field = file_field;
  this.results = results;

  file_field.on("change", this.field_changed_event.bindAsEventListener(this));
}

UploadSimilarSearch.prototype.field_changed_event = function(event)
{
  this.results.hide();

  if(this.file_field.files == null || this.file_field.files.length == 0)
    return;

  this.results.innerHTML = "Searching...";
  this.results.show();

  var file = this.file_field.files[0];
  var similar = new ThumbnailUserImage(file, this.thumbnail_complete.bind(this));
}

UploadSimilarSearch.prototype.thumbnail_complete = function(result)
{
  if(!result.success)
  {
    this.results.innerHTML = "Image load failed.";
    this.results.show();
    return;
  }

  /* Grab a data URL from the canvas; this is what we'll send to the server. */
  var data_url = result.canvas.toDataURL();

  /* Create the FormData containing the thumbnail image we're sending. */
  var form_data = new FormData();
  form_data.append("url", data_url);

  var req = new Ajax.Request("/post/similar.json", {
    method: "post",
    postBody: form_data,

    /* Tell Prototype not to change XHR's contentType; it breaks FormData. */
    contentType: null,

    onComplete: function(resp)
    {
      this.results.innerHTML = "";
      this.results.show();

      var json = resp.responseJSON;
      if(!json.success)
      {
        this.results.innerHTML = json.reason;
        return;
      }

      if(json.posts.length > 0)
      {
        var posts = [];
        var shown_posts = 3;
        json.posts.slice(0, shown_posts).each(function(post) {
            var url;
            if(User.get_use_browser())
              url = "/post/browse#" + post.id;
            else
              url = "/post/show/" + post.id;
            var s = "<a href='" + url + "'>post #" + post.id + "</a>";
            posts.push(s);
        });
        var post_links = posts.join(", ");
        var see_all = "<a href='/post/similar?search_id=" + json.search_id + "'>(see all)</a>";
        var html = "Similar posts " + see_all + ": " + post_links;

        if(json.posts.length > shown_posts)
        {
          var remaining_posts = json.posts.length - shown_posts;
          html += " (" + remaining_posts + " more)";
        }

        this.results.innerHTML = html;
      }
      else
      {
        this.results.innerHTML = "No similar posts found.";
      }
    }.bind(this)
  });
}

