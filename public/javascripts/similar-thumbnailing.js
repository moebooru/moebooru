SimilarWithThumbnailing = function(form)
{
  this.supported = false;

  /* Stop if canvas isn't supported, and just use regular form submission. */
  this.canvas = create_canvas_2d();
  if(!this.canvas)
    return;

  /* Stop if the FormData API isn't supported. */
  if(!("FormData" in window))
    return;

  this.supported = true;
  this.form = form;
  this.image = document.createElement("IMG");

  form.on("submit", this.form_submit_event.bindAsEventListener(this));
  this.image.on("load", this.image_load_event.bindAsEventListener(this));
  this.image.on("abort", this.image_abort_event.bindAsEventListener(this));
  this.image.on("error", this.image_error_event.bindAsEventListener(this));
}

SimilarWithThumbnailing.prototype.form_submit_event = function(e)
{
  var post_file = this.form.down("#file");

  /* If the files attribute isn't supported, or we have no file (source upload), use regular
   * form submission. */
  if(post_file.files == null || post_file.files.length == 0)
    return;

  /* If we failed to load the image last time due to a silent Chrome error, continue with
   * the submission normally this time. */
  var file = post_file.files[0];
  if(this.force_file && this.force_file == file)
  {
    this.force_file = null;
    return;
  }

  e.stop();

  document.documentElement.addClassName("progress");

  this.file = file;
  var url = createObjectURL(this.file);

  this.image.src = url;
}

/* When the image finishes loading after form_submit_event sets it, update the canvas
 * thumbnail from it. */
SimilarWithThumbnailing.prototype.image_load_event = function(e)
{
  /* Reduce the image size to thumbnail resolution. */
  var width = this.image.width;
  var height = this.image.height;
  var max_width = 128;
  var max_height = 128;
  if(width > max_width)
  {
    var ratio = max_width/width;
    height *= ratio; width *= ratio;
  }
  if(height > max_height)
  {
    var ratio = max_height/height;
    height *= ratio; width *= ratio;
  }
  width = Math.round(width);
  height = Math.round(height);

  /* Set the canvas to the image size we want. */
  var canvas = this.canvas;
  canvas.width = width;
  canvas.height = height;

  /* Blit the image onto the canvas. */
  var ctx = canvas.getContext("2d");

  /* Clear the canvas, so check_image_contents can check that the data was correctly loaded. */
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  ctx.drawImage(this.image, 0, 0, canvas.width, canvas.height);

  document.documentElement.removeClassName("progress");

  if(!this.check_image_contents())
  {
    notice("The image failed to load; submitting normally...");
    this.force_file = this.file;

    /* Resend the submit event.  Defer it, so the notice can take effect before we
     * navigate off the page. */
    (function() { this.form.simulate_submit(); }).bind(this).defer();

    return;
  }

  this.submit();
}

/*
 * Work around a Chrome bug.  When very large images fail to load, we still get
 * onload and the image acts like a loaded, completely transparent image, instead
 * of firing onerror.  This makes it difficult to tell if the image actually loaded
 * or not.  Check that the image loaded by looking at the results; reject the image
 * if it's completely transparent.
 */
SimilarWithThumbnailing.prototype.check_image_contents = function()
{
  var ctx = this.canvas.getContext("2d");
  var image = ctx.getImageData(0, 0, this.canvas.width, this.canvas.height);
  var data = image.data;

  /* Iterate through the alpha components, and search for any nonzero value. */
  var idx = 3;
  var max_idx = image.width * image.height * 4;
  while(idx < max_idx)
  {
    if(data[idx] != 0)
      return true;
    idx += 4;
  }
  return false;
}

SimilarWithThumbnailing.prototype.image_abort_event = function(e)
{
  document.documentElement.removeClassName("progress");
}

/* This happens on normal errors, usually because the file isn't a supported image. */
SimilarWithThumbnailing.prototype.image_error_event = function(e)
{
  document.documentElement.removeClassName("progress");
  alert("The file couldn't be loaded.");
}

/* Submit a post/similar request using the image currently in the canvas. */
SimilarWithThumbnailing.prototype.submit = function()
{
  /* Grab a data URL from the canvas; this is what we'll send to the server. */
  var data_url = this.canvas.toDataURL();

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
      var json = resp.responseJSON;
      if(!json.success)
      {
        notice(json.reason);
        return;
      }

      /* Redirect to the search results. */
      window.location.href = "/post/similar?search_id=" + json.search_id;
    }
  });
}

