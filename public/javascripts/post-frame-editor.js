var create_drag_box = function(div)
{
  var create_handle = function(cursor, style)
  {
    var handle = $(document.createElement("div"));
    handle.style.position = "absolute";
    handle.className = "frame-box-handle " + cursor;
    handle.frame_drag_cursor = cursor;

    handle.style.pointerEvents = "all";
    div.appendChild(handle);
    for(s in style)
    {
      handle.style[s] = style[s];
    }
    return handle;
  }

  /* Create the corner handles after the edge handles, so they're on top. */
  create_handle("n-resize", {top: "-5px", width: "100%", height: "10px"});
  create_handle("s-resize", {bottom: "-5px", width: "100%", height: "10px"});
  create_handle("w-resize", {left: "-5px", height: "100%", width: "10px"});
  create_handle("e-resize", {right: "-5px", height: "100%", width: "10px"});
  create_handle("nw-resize", {top: "-5px", left: "-5px", height: "10px", width: "10px"});
  create_handle("ne-resize", {top: "-5px", right: "-5px", height: "10px", width: "10px"});
  create_handle("sw-resize", {bottom: "-5px", left: "-5px", height: "10px", width: "10px"});
  create_handle("se-resize", {bottom: "-5px", right: "-5px", height: "10px", width: "10px"});
}

var apply_drag = function(dragging_mode, x, y, image_dimensions, box)
{
  var move_modes = {
    "move": { left: +1, top: +1, bottom: +1, right: +1 },
    "n-resize": { top: +1 },
    "s-resize": { bottom: +1 },
    "w-resize": { left: +1 },
    "e-resize": { right: +1 },
    "nw-resize": { top: +1, left: +1 },
    "ne-resize": { top: +1, right: +1 },
    "sw-resize": { bottom: +1, left: +1 },
    "se-resize": { bottom: +1, right: +1 }
  }
  var mode = move_modes[dragging_mode];
  var result = {
    left: box.left,
    top: box.top,
    width: box.width,
    height: box.height
  };
  var right = result.left + result.width;
  var bottom = result.top + result.height;

  if(dragging_mode == "move")
  {
    /* In move mode, clamp the movement.  In other modes, clip the size below. */
    x = clamp(x, -result.left, image_dimensions.width-right);
    y = clamp(y, -result.top, image_dimensions.height-bottom);
  }

  /* Apply the drag. */
  if(mode.top != null)     result.top += y * mode.top;
  if(mode.left != null)    result.left += x * mode.left;
  if(mode.right != null)   right += x * mode.right;
  if(mode.bottom != null)  bottom += y * mode.bottom;

  if(dragging_mode != "move")
  {
    /* Only clamp the dimensions that were modified. */
    if(mode.left != null)   result.left = clamp(result.left, 0, right-1);
    if(mode.top != null)    result.top = clamp(result.top, 0, bottom-1);
    if(mode.bottom != null) bottom = clamp(bottom, result.top+1, image_dimensions.height);
    if(mode.right != null)  right = clamp(right, result.left+1, image_dimensions.width);
  }

  result.width = right - result.left;
  result.height = bottom - result.top;
  return result;
}

/*
 * Given a frame, its post and an image, return the frame's rectangle scaled to
 * the size of the image.
 */
var frame_dimensions_to_image = function(frame, image, post)
{
  var result = {
    top: frame.source_top,
    left: frame.source_left,
    width: frame.source_width,
    height: frame.source_height
  };
  result.left *= image.width / post.width;
  result.top *= image.height / post.height;
  result.width *= image.width / post.width;
  result.height *= image.height / post.height;

  result.top = Math.round(result.top); result.left = Math.round(result.left);
  result.width = Math.round(result.width); result.height = Math.round(result.height);

  return result;
}

/*
 * Convert dimensions scaled to an image back to the source resolution.
 */
var frame_dimensions_from_image = function(frame, image, post)
{
  var result = {
    source_top: frame.top,
    source_left: frame.left,
    source_width: frame.width,
    source_height: frame.height
  };

  /* Scale the coordinates back into the source resolution. */
  result.source_top /= image.height / post.height;
  result.source_left /= image.width / post.width;
  result.source_height /= image.height / post.height;
  result.source_width /= image.width / post.width;

  result.source_top = Math.round(result.source_top); result.source_left = Math.round(result.source_left);
  result.source_width = Math.round(result.source_width); result.source_height = Math.round(result.source_height);
  return result;
}

FrameEditor = function(container, image_container, popup_container, options)
{
  this.container = container;
  this.popup_container = popup_container;
  this.image_container = image_container;
  this.options = options;
  this.show_corner_drag = true;

  this.image_frames = [];

  /* Event handlers which are set only while the tag editor is open: */
  this.open_handlers = [];

  /* Set up the four parts of the corner dragger. */
  var popup_parts = [".frame-editor-nw", ".frame-editor-ne", ".frame-editor-sw", ".frame-editor-se"];
  this.corner_draggers = [];
  for(var i = 0; i < popup_parts.length; ++i)
  {
    var part = popup_parts[i];
    var div = this.popup_container.down(part);
    var corner_dragger = new CornerDragger(div, part, {
      onUpdate: function() {
        this.update_frame_in_list(this.editing_frame);
        this.update_image_frame(this.editing_frame);
      }.bind(this)
    });
    this.corner_draggers.push(corner_dragger);
  }

  /* Create the main frame.  This sits on top of the image, receives mouse events and
   * holds the individual frames. */
  var div = $(document.createElement("div"));
  div.style.position = "absolute";
  div.style.left = "0";
  div.style.top = "0";
  div.className = "frame-editor-main-frame";
  this.image_container.appendChild(div);
  this.main_frame = div;
  this.main_frame.hide();

  /* Frame editor buttons: */
  this.container.down(".frame-editor-add").on("click", function(e) { e.stop(); this.add_frame(); }.bindAsEventListener(this));

  /* Buttons in the frame table: */
  this.container.on("click", ".frame-label", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.focus(frame_idx);
  }.bind(this));

  this.container.on("click", ".frame-delete", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.delete_frame(frame_idx);
  }.bind(this));

  this.container.on("click", ".frame-up", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.move_frame(frame_idx, frame_idx-1);
  }.bind(this));

  this.container.on("click", ".frame-down", function(e, element) {
    e.stop();
    var frame_idx = element.up(".frame-row").frame_idx;
    this.move_frame(frame_idx, frame_idx+1);
  }.bind(this));

  this.container.down("table").on("change", function(e) {
    this.form_data_changed();
  }.bind(this));
}

FrameEditor.prototype.move_frame = function(frame_idx, frame_idx_target)
{
  var post = Post.posts.get(this.post_id);

  frame_idx_target = Math.max(frame_idx_target, 0);
  frame_idx_target = Math.min(frame_idx_target, post.frames_pending.length-1);
  if(frame_idx == frame_idx_target)
    return;

  var frame = post.frames_pending[frame_idx];
  post.frames_pending.splice(frame_idx, 1);
  post.frames_pending.splice(frame_idx_target, 0, frame);

  this.repopulate_table();

  /* Reset the focus.  If the item that was moved was focused, focus on it in
   * its new position. */
  var editing_frame = this.editing_frame == frame_idx? frame_idx_target:this.editing_frame;
  this.editing_frame = null;
  this.focus(editing_frame);
}

FrameEditor.prototype.form_data_changed = function()
{
  var post = Post.posts.get(this.post_id);
  for(var i = 0; i < post.frames_pending.length; ++i)
    this.update_frame_from_list(i);
  this.update();
}

FrameEditor.prototype.set_drag_to_create = function(enable)
{
  this.drag_to_create = enable;
}

FrameEditor.prototype.update_show_corner_drag = function()
{
  var shown = this.post_id != null && this.editing_frame != null && this.show_corner_drag;
  if(Prototype.Browser.WebKit)
  {
    /* Work around a WebKit (maybe just a Chrome) issue.  Images are downloaded immediately, but
     * they're only decompressed the first time they're actually painted on screen.  This happens
     * late, after all style is applied: hiding with display: none, visibility: hidden or even
     * opacity: 0 causes the image to not be decoded until it's displayed, which causes a huge
     * UI hitch the first time the user drags a box.  Work around this by setting opacity very
     * small; it'll trick it into decoding the image, but it'll clip to 0 when rendered. */
    if(shown)
    {
      this.popup_container.style.opacity = 1;
      this.popup_container.style.pointerEvents = "";
      this.popup_container.style.position = "static";
    }
    else
    {
      this.popup_container.style.opacity = 0.001;

      /* Make sure the invisible element doesn't interfere with the page; disable pointer-events
       * so it doesn't receive clicks, and set it to absolute so it doesn't affect the size of its
       * containing box. */
      this.popup_container.style.pointerEvents = "none";
      this.popup_container.style.position = "absolute";
      this.popup_container.style.top = "0px";
      this.popup_container.style.right = "0px";
    }
    this.popup_container.show();
  }
  else
  {
    this.popup_container.show(shown);
  }

  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].update();
}

FrameEditor.prototype.set_show_corner_drag = function(enable)
{
  this.show_corner_drag = enable;
  this.update_show_corner_drag();
}

FrameEditor.prototype.set_image_dimensions = function(width, height)
{
  var editing_frame = this.editing_frame;
  var post_id = this.post_id;

  this.close();

  this.image_dimensions = {width: width, height: height};
  this.main_frame.style.width = this.image_dimensions.width + "px";
  this.main_frame.style.height = this.image_dimensions.height + "px";

  if(post_id != null)
  {
    this.open(post_id);
    this.focus(editing_frame);
  }
}

/*
 * Like document.elementFromPoint, but returns an array of all elements at the given point.
 * If a top element is specified, stop if it's reached without including it in the list.
 *
 */
var elementArrayFromPoint = function(x, y, top)
{
  var elements = [];
  while(1)
  {
    var element = document.elementFromPoint(x, y);
    if(element == this.main_frame || element == document.documentElement)
      break;
    element.original_display = element.style.display;
    element.style.display = "none";
    elements.push(element);
  }

  /* Restore the elements we just hid. */
  elements.each(function(e) {
    e.style.display = e.original_display;
    e.original_display = null;
  });

  return elements;
}

FrameEditor.prototype.is_opened = function()
{
  return this.post_id != null;
}

/* Open the frame editor if it isn't already, and focus on the specified frame. */
FrameEditor.prototype.open = function(post_id)
{
  if(this.image_dimensions == null)
    throw "Must call set_image_dimensions before open";
  if(this.post_id != null)
    return;
  this.post_id = post_id;
  this.editing_frame = null;
  this.dragging_item = null;

  this.container.show();
  this.main_frame.show();
  this.update_show_corner_drag();

  var post = Post.posts.get(this.post_id);

  /* Tell the corner draggers which post we're working on now, so they'll start
   * loading the JPEG version immediately if necessary.  Otherwise, we'll start
   * loading it the first time we focus a frame, which will hitch the editor for
   * a while in Chrome. */
  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].set_post_id(this.post_id);

  this.open_handlers.push(
    document.on("keydown", function(e) {
      if (e.keyCode == Event.KEY_ESC) { this.discard(); }
    }.bindAsEventListener(this))
  )

  /* If we havn't done so already, make a backup of this post's frames.  We'll restore
   * from this later if the user cancels the edit. */
  this.original_frames = Object.toJSON(post.frames_pending);

  this.repopulate_table();

  this.create_dragger();

  if(post.frames_pending.length > 0)
    this.focus(0);

  this.update();
}

FrameEditor.prototype.create_dragger = function()
{
  if(this.dragger)
    this.dragger.destroy();

  this.dragger = new DragElement(this.main_frame, {
    ondown: function(e) {
      var post = Post.posts.get(this.post_id);

      /*
       * Figure out which element(s) we're clicking on.  The click may lie on a spot
       * where multiple frames overlap; make a list.
       *
       * Temporarily enable pointerEvents on the frames, so elementFromPoint will
       * resolve them.
       */
      this.image_frames.each(function(frame) { frame.style.pointerEvents = "all"; });
      var clicked_elements = elementArrayFromPoint(e.x, e.y, this.main_frame);
      this.image_frames.each(function(frame) { frame.style.pointerEvents = "none"; });

      /* If we clicked on a handle, prefer it over frame bodies at the same spot. */
      var element = null;
      clicked_elements.each(function(e) {
        /* If a handle was clicked, always prefer it.  Use the first handle we find,
         * so we prefer the corner handles (which are always on top) to edge handles. */
        if(element == null && e.hasClassName("frame-box-handle"))
          element = e;
      }.bind(this));

      /* If a handle wasn't clicked, prefer the frame that's currently focused. */
      if(element == null)
      {
        clicked_elements.each(function(e) {
          if(!e.hasClassName("frame-editor-frame-box"))
            e = e.up(".frame-editor-frame-box");
          if(this.image_frames.indexOf(e) == this.editing_frame)
            element = e;
        }.bind(this));
      }

      /* Otherwise, just use the first item that was found. */
      if(element == null)
        element = clicked_elements[0];

      /* If a handle was clicked on, find the frame element that contains it. */
      var frame_element = element;
      if(!frame_element.hasClassName("frame-editor-frame-box"))
        frame_element = frame_element.up(".frame-editor-frame-box");

      /* If we didn't click on a frame box at all, create a new one. */
      if(frame_element == null)
      {
        if(!this.drag_to_create)
          return;

        this.dragging_new = true;
      }
      else
        this.dragging_new = false;

      /* If the element we actually clicked on was one of the edge handles, set the drag
       * mode based on which one was clicked. */
      if(element.hasClassName("frame-box-handle"))
        this.dragging_mode = element.frame_drag_cursor
      else
        this.dragging_mode = "move";

      if(frame_element && frame_element.hasClassName("frame-editor-frame-box"))
      {
        var frame_idx = this.image_frames.indexOf(frame_element);
        this.dragging_idx = frame_idx;

        var frame = post.frames_pending[this.dragging_idx];
        this.dragging_anchor = frame_dimensions_to_image(frame, this.image_dimensions, post);
      }

      this.focus(this.dragging_idx);

      /* If we're dragging a handle, override the drag class so the pointer will
       * use the handle pointer instead of the drag pointer. */
      this.dragger.overriden_drag_class = this.dragging_mode == "move"? null: this.dragging_mode;

      this.dragger.options.snap_pixels = this.dragging_new? 10:0;

      /* Stop propagation of the event, so any other draggers in the chain don't start.  In
       * particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
       * Only do this if we're actually dragging, not if we aborted due to this.drag_to_create. */
      e.latest_event.stopPropagation();
    }.bind(this),

    onup: function(e) {
      this.dragging_idx = null;
      this.dragging_anchor = null;
    }.bind(this),

    ondrag: function(e) {
      var post = Post.posts.get(this.post_id);

      if(this.dragging_new)
      {
        /* Pick a dragging mode based on which way we were dragged.  This is a
         * little funny; we should probably be able to drag freely, not be fixed
         * to the first direction we drag. */
        if(e.aX > 0 && e.aY > 0)        this.dragging_mode = "se-resize";
        else if(e.aX > 0 && e.aY < 0)   this.dragging_mode = "ne-resize";
        else if(e.aX < 0 && e.aY > 0)   this.dragging_mode = "sw-resize";
        else if(e.aX < 0 && e.aY < 0)   this.dragging_mode = "nw-resize";
        else return;

        this.dragging_new = false;

        /* Create a new, empty frame.  When we get to the regular drag path below we'll
         * give it its real size, based on how far we've dragged so far. */
        var frame_offset = this.main_frame.cumulativeOffset();
        var dims = {
          left: e.dragger.anchor_x - frame_offset.left,
          top: e.dragger.anchor_y - frame_offset.top,
          height: 0,
          width: 0
        };
        this.dragging_anchor = dims;

        var source_dims = frame_dimensions_from_image(dims, this.image_dimensions, post);
        this.dragging_idx = this.add_frame(source_dims);
        post.frames_pending[this.editing_frame] = source_dims;
      }

      if(this.dragging_idx == null)
        return;

      var dims = apply_drag(this.dragging_mode, e.aX, e.aY, this.image_dimensions, this.dragging_anchor);

      /* Scale the changed dimensions back to the source resolution and apply them
       * to the frame. */
      var source_dims = frame_dimensions_from_image(dims, this.image_dimensions, post);
      post.frames_pending[this.editing_frame] = source_dims;

      this.update_frame_in_list(this.editing_frame);
      this.update_image_frame(this.editing_frame);
    }.bind(this)
  });
}

FrameEditor.prototype.repopulate_table = function()
{
  var post = Post.posts.get(this.post_id);

  /* Clear the table. */
  var tbody = this.container.down(".frame-list").down("TBODY");
  while(tbody.firstChild)
    tbody.removeChild(tbody.firstChild);

  /* Clear the image frames. */
  this.image_frames.each(function(f) {
    f.parentNode.removeChild(f);
  }.bind(this));
  this.image_frames = [];

  for(var i = 0; i < post.frames_pending.length; ++i)
  {
    this.add_frame_to_list(i);
    this.create_image_frame();
    this.update_image_frame(i);
  }
}

FrameEditor.prototype.update = function()
{
  this.update_show_corner_drag();

  if(this.image_dimensions == null)
    return;

  var post = Post.posts.get(this.post_id);
  if(post != null)
  {
    for(var i = 0; i < post.frames_pending.length; ++i)
      this.update_image_frame(i);
  }
}

/* If the frame editor is open, discard changes and close it. */
FrameEditor.prototype.discard = function()
{
  if(this.post_id == null)
    return;

  /* Save revert_to, and close the editor before reverting, to make sure closing
   * the editor doesn't change anything. */
  var revert_to = this.original_frames;
  var post_id = this.post_id;
  this.close();

  /* Revert changes. */
  var post = Post.posts.get(post_id);
  post.frames_pending = revert_to.evalJSON();
}

/* Get the frames specifier for the post's frames. */
FrameEditor.prototype.get_current_frames_spec = function()
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending;
  var frame_specs = [];
  post.frames_pending.each(function(frame) {
    var s = frame.source_left + "x" + frame.source_top + "," + frame.source_width + "x" + frame.source_height;
    frame_specs.push(s);
  }.bind(this));
  return frame_specs.join(";");
}


/* Return true if the frames have been changed. */
FrameEditor.prototype.changed = function()
{
  var post = Post.posts.get(this.post_id);
  var spec = this.get_current_frames_spec();
  return spec != post.frames_pending_string;
}

/* Save changes to the post, if any.  If not null, call finished on completion. */
FrameEditor.prototype.save = function(finished)
{
  if(this.post_id == null)
  {
    if(finished)
      finished();
    return;
  }

  /* Save the current post_id, so it's preserved when the AJAX completion function
   * below is run. */
  var post_id = this.post_id;
  var post = Post.posts.get(post_id);
  var frame = post.frames_pending;

  var spec = this.get_current_frames_spec();
  if(spec == post.frames_pending_string)
  {
    if(finished)
      finished();
    return;
  }

  Post.update_batch([{
    id: post_id,
    frames_pending_string: spec
  }], function(posts)
  {
    if(this.post_id == post_id)
    {
      /* The registered post has been changed, and we're still displaying it.  Grab the
       * new version, and updated original_frames so we no longer consider this post
       * changed. */
      var post = Post.posts.get(post_id);
      this.original_frames = Object.toJSON(post.frames_pending);

      /* In the off-chance that the frames_pending that came back differs from what we
       * requested, update the display. */
      this.update();
    }

    if(finished)
      finished();
  }.bind(this));
}

FrameEditor.prototype.create_image_frame = function()
{
  var div = $(document.createElement("div"));
  div.className = "frame-editor-frame-box";

  /* Disable pointer-events on the image frame, so the handle cursors always
   * show up even when an image frame lies on top of it. */
  div.style.pointerEvents = "none";

  // div.style.opacity=0.1;
  this.main_frame.appendChild(div);
  this.image_frames.push(div);

  create_drag_box(div);


}

FrameEditor.prototype.update_image_frame = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[frame_idx];

  /* If the focused frame is being modified, update the corner dragger as well. */
  if(frame_idx == this.editing_frame)
  {
    for(var i = 0; i < this.corner_draggers.length; ++i)
      this.corner_draggers[i].update();
  }

  var dimensions = frame_dimensions_to_image(frame, this.image_dimensions, post);

  var div = this.image_frames[frame_idx];
  div.style.left = dimensions.left + "px";
  div.style.top = dimensions.top + "px";
  div.style.width = dimensions.width + "px";
  div.style.height = dimensions.height + "px";

  if(frame_idx == this.editing_frame)
    div.addClassName("focused-frame-box");
  else
    div.removeClassName("focused-frame-box");
}

/* Append the given frame to the editor list. */
FrameEditor.prototype.add_frame_to_list = function(frame_idx)
{
  var tbody = this.container.down(".frame-list").down("TBODY");
  var tr = $(document.createElement("TR"));
  tr.className = "frame-row frame-" + frame_idx;
  tr.frame_idx = frame_idx;
  tbody.appendChild(tr);

  var html = "<td><span class='frame-label'>Frame " + frame_idx + "</span></td>";
  html += "<td><input class='frame-left frame-dims' size=4></td>";
  html += "<td><input class='frame-top frame-dims' size=4></td>";
  html += "<td><input class='frame-width frame-dims' size=4></td>";
  html += "<td><input class='frame-height frame-dims' size=4></td>";
  html += "<td><a class='frame-delete frame-button-box' href='#'>X</a></td>";
  html += "<td><a class='frame-up frame-button-box' href='#'>⇡</a></td>";
  html += "<td><a class='frame-down frame-button-box' href='#'>⇣</a></td>";
  tr.innerHTML = html;

  this.update_frame_in_list(frame_idx);
}

/* Update the fields of frame_idx in the table. */
FrameEditor.prototype.update_frame_in_list = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[frame_idx];

  var tbody = this.container.down(".frame-list").down("TBODY");
  var tr = tbody.down(".frame-" + frame_idx);

  tr.down(".frame-left").value = frame.source_left;
  tr.down(".frame-top").value = frame.source_top;
  tr.down(".frame-width").value = frame.source_width;
  tr.down(".frame-height").value = frame.source_height;
}

/* Commit changes in the frame list to the frame. */
FrameEditor.prototype.update_frame_from_list = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[frame_idx];

  var tbody = this.container.down(".frame-list").down("TBODY");
  var tr = tbody.down(".frame-" + frame_idx);

  frame.source_left = tr.down(".frame-left").value;
  frame.source_top = tr.down(".frame-top").value;
  frame.source_width = tr.down(".frame-width").value;
  frame.source_height = tr.down(".frame-height").value;
}

/* Add a new default frame to the end of the list, update the table, and edit the new frame. */
FrameEditor.prototype.add_frame = function(new_frame)
{
  var post = Post.posts.get(this.post_id);

  if(new_frame == null)
    new_frame = {
      source_top: post.height * 1/4,
      source_left: post.width * 1/4,
      source_width: post.width / 2,
      source_height: post.height / 2
    };

  post.frames_pending.push(new_frame);
  this.add_frame_to_list(post.frames_pending.length-1);
  this.create_image_frame();
  this.update_image_frame(post.frames_pending.length-1);

  this.focus(post.frames_pending.length-1);
  return post.frames_pending.length-1;
}

/* Delete the specified frame. */
FrameEditor.prototype.delete_frame = function(frame_idx)
{
  var post = Post.posts.get(this.post_id);

  /* If we're editing this frame, switch to a nearby one. */
  var switch_to_frame = null;
  if(this.editing_frame == frame_idx)
  {
    switch_to_frame = this.editing_frame;
    this.focus(null);

    /* If we're deleting the bottom item on the list, switch to the item above it instead. */
    if(frame_idx == post.frames_pending.length-1)
      --switch_to_frame;

    /* If that put it over the top, we're deleting the only item.  Focus no item. */
    if(switch_to_frame < 0)
      switch_to_frame = null;
  }

  /* Remove the frame from the array. */
  post.frames_pending.splice(frame_idx, 1);

  /* Renumber the table. */
  this.repopulate_table();

  /* Focus switch_to_frame, if any. */
  this.focus(switch_to_frame);
}

FrameEditor.prototype.focus = function(post_frame)
{
  if(this.editing_frame == post_frame)
    return;

  if(this.editing_frame != null)
  {
    var row = this.container.down(".frame-" + this.editing_frame);
    row.removeClassName("frame-focused");
  }

  this.editing_frame = post_frame;

  if(this.editing_frame != null)
  {
    var row = this.container.down(".frame-" + this.editing_frame);
    row.addClassName("frame-focused");
  }

  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].set_post_frame(this.editing_frame);

  this.update();
}

/* Close the frame editor.  Local changes are not saved or reverted. */
FrameEditor.prototype.close = function()
{
  if(this.post_id == null)
    return;
  this.post_id = null;

  this.editing_frame = null;

  for(var i = 0; i < this.corner_draggers.length; ++i)
    this.corner_draggers[i].set_post_id(null);

  if(this.keydown_handler)
  {
    this.open_handlers.each(function(h) { h.stop(); });
    this.open_handlers = [];
  }

  if(this.dragger)
    this.dragger.destroy();
  this.dragger = null;

  this.container.hide();
  this.main_frame.hide();
  this.update_show_corner_drag();

  /* Clear the row table. */
  var tbody = this.container.down(".frame-list").down("TBODY");
  while(tbody.firstChild)
    tbody.removeChild(tbody.firstChild);

  this.original_frames = null;
  this.update();

  if(this.options.onClose)
    this.options.onClose(this);
}

/* Create the specified corner dragger. */
CornerDragger = function(container, part, options)
{
  this.container = container;
  this.part = part;
  this.options = options;

  var box = container.down(".frame-editor-popup-div");

  /* Create a div inside each .frame-editor-popup-div floating on top of the image
   * to show the border of the frame. */
  var frame_box = $(document.createElement("div"));
  frame_box.className = "frame-editor-frame-box";
  create_drag_box(frame_box);
  box.appendChild(frame_box);

  this.dragger = new DragElement(box, {
    snap_pixels: 0,

    ondown: function(e) {
      var element = document.elementFromPoint(e.x, e.y);

      /* If we clicked on a drag handle, use that handle.  Otherwise, choose the corner drag
       * handle for the corner we're in. */
      if(element.hasClassName("frame-box-handle")) this.dragging_mode = element.frame_drag_cursor;
      else if(part == ".frame-editor-nw") this.dragging_mode = "nw-resize";
      else if(part == ".frame-editor-ne") this.dragging_mode = "ne-resize";
      else if(part == ".frame-editor-sw") this.dragging_mode = "sw-resize";
      else if(part == ".frame-editor-se") this.dragging_mode = "se-resize";

      var post = Post.posts.get(this.post_id);
      var frame = post.frames_pending[this.post_frame];
      this.dragging_anchor = frame_dimensions_to_image(frame, this.image_dimensions, post);

      /* When dragging a handle, hide the cursor to get it out of the way. */
      this.dragger.overriden_drag_class = this.dragging_mode == "move"? null: "hide-cursor";

      /* Stop propagation of the event, so any other draggers in the chain don't start.  In
       * particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
       * Only do this if we're actually dragging, not if we aborted due to this.drag_to_create. */
      e.latest_event.stopPropagation();
    }.bind(this),

    ondrag: function(e) {
      var post = Post.posts.get(this.post_id);

      /* Invert the motion, since we're dragging the image around underneith the
       * crop frame instead of dragging the crop frame around. */
      var dims = apply_drag(this.dragging_mode, -e.aX, -e.aY, this.image_dimensions, this.dragging_anchor);

      /* Scale the changed dimensions back to the source resolution and apply them
       * to the frame. */
      var source_dims = frame_dimensions_from_image(dims, this.image_dimensions, post);
      post.frames_pending[this.post_frame] = source_dims;

      if(this.options.onUpdate)
        this.options.onUpdate();
    }.bind(this)
  });

  this.update();
}

/*
 * Set the post to show in the corner dragger.  If post_id is null, clear any displayed
 * post.
 *
 * When the post ID is set, the post frame is always cleared.
 */
CornerDragger.prototype.set_post_id = function(post_id)
{
  this.post_id = post_id;
  this.post_frame = null;

  var url = null;
  var img = this.container.down("img");
  if(post_id != null)
  {
    var post = Post.posts.get(this.post_id);
    this.image_dimensions = {
      width: post.jpeg_width, height: post.jpeg_height
    };

    url = post.jpeg_url;
    img.width = this.image_dimensions.width;
    img.height = this.image_dimensions.height;
  }

  /* Don't change the image if it's already set; it causes Chrome to reprocess the
   * image. */
  if(img.src != url)
  {
    img.src = url;

    if(Prototype.Browser.WebKit && url)
    {
      /* Decoding in Chrome takes long enough to be visible.  Hourglass the cursor while it runs. */
      document.documentElement.addClassName("hourglass");
      (function() { document.documentElement.removeClassName("hourglass"); }.defer());
    }
  }

  this.update();
}

CornerDragger.prototype.set_post_frame = function(post_frame)
{
  this.post_frame = post_frame;

  this.update();
}

CornerDragger.prototype.update = function()
{
  if(this.post_id == null || this.post_frame == null)
    return;

  var post = Post.posts.get(this.post_id);
  var frame = post.frames_pending[this.post_frame];
  var dims = frame_dimensions_to_image(frame, this.image_dimensions, post);

  var div = this.container;

  /* Update the drag/frame box. */
  var box = this.container.down(".frame-editor-frame-box");
  box.style.left = dims.left + "px";
  box.style.top = dims.top + "px";
  box.style.width = dims.width + "px";
  box.style.height = dims.height + "px";

  /* Recenter the corner box. */
  var top = dims.top;
  var left = dims.left;
  if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se")
    left += dims.width;
  if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se")
    top += dims.height;

  var offset_height = div.offsetHeight/2;
  var offset_width = div.offsetWidth/2;
  /*
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-ne") offset_height -= div.offsetHeight/4;
  if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se") offset_height += div.offsetHeight/4;
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-sw") offset_width -= div.offsetWidth/4;
  if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se") offset_width += div.offsetWidth/4;
  */
  left -= offset_width;
  top -= offset_height;

  /* If the region is small enough that we don't have enough to fill the corner
   * frames, push the frames inward so they line up. */
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-sw")
    left = Math.min(left, dims.left + dims.width/2 - div.offsetWidth);
  if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se")
    left = Math.max(left, dims.left + dims.width/2);
  if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-ne")
    top = Math.min(top, dims.top + dims.height/2 - div.offsetHeight);
  if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se")
    top = Math.max(top, dims.top + dims.height/2);

  var img = this.container.down(".frame-editor-popup-div");
  img.style.marginTop = (-top) + "px";
  img.style.marginLeft = (-left) + "px";
}

