var PostUploadForm = function(form, progress)
{
  var XHRLevel2 = (new XMLHttpRequest().upload != null);
  var SupportsFormData = "FormData" in window;
  if(!XHRLevel2 || !SupportsFormData)
    return;
  
  this.form_element = form;
  this.cancel_element = this.form_element.down(".cancel");

  this.progress = progress;
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
      window.location.href = json.location;
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

