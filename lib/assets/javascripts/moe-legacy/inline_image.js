InlineImage = {
  mouse_down: null,
  zoom_levels:
  [
    1.0, 1.5, 2.0, 4.0
  ],
  get_zoom: function(level)
  {
    if(level >= 0)
      return InlineImage.zoom_levels[level];
    else
      return 1 / InlineImage.zoom_levels[-level];
  },

  register: function(id, data)
  {
    var container = $(id);
    data.html_id = id;
    container.inline_image = data;

    /* initted is set to true after the image has been opened and the large images
     * inside have been created by expand(). */
    data.initted = false;
    data.expanded = false;
    data.toggled_from = null;
    data.current = -1;
    data.zoom_level = 0;

    {
      var ui_html = "";
      if(data.images.length > 1)
      {
        for(var idx = 0; idx < data.images.length; ++idx)
        {
          // html_id looks like "inline-123-456".  Mark the button for each individual image as "inline-123-456-2".
          var button_id = data.html_id + "-" + idx;
          var text = data.images[idx].description.escapeHTML();
          if(text == "")
            text = "#" + (idx + 1);

          ui_html += "<a href='#' id='" + button_id + "' class='select-image' onclick='InlineImage.show_image_no(\"" + data.html_id + "\", " + idx + "); return false;'>" + text + "</a>";
        }
      }
      ui_html += "<a href='#' class='select-image' onclick='InlineImage.zoom(\"" + data.html_id + "\", +1); return false;'>+</a>";
      ui_html += "<a href='#' class='select-image' onclick='InlineImage.zoom(\"" + data.html_id + "\", -1); return false;'>-</a>";
      var zoom_id = data.html_id + "-zoom";
      ui_html += "<a href='#' id='" + zoom_id + "' class='select-image' onclick='InlineImage.zoom(\"" + data.html_id + "\", 0); return false;'>100%</a>";
      ui_html += "<a href='#' class='select-image' onclick='InlineImage.close(\"" + data.html_id + "\"); return false;'>Close</a>";

      ui_html += "<a href='/inline/edit/" + data.id + "' class='edit-link'>Image&nbsp;#" + data.id + "</a>";

      container.down(".expanded-image-ui").innerHTML = ui_html;
    }

    container.down(".inline-thumb").observe("click", function(e) {
      e.stop();
      InlineImage.expand(data.html_id);
    });
    container.observe("dblclick", function(e) {
      e.stop();
    });

    var viewer_img = container.down(".main-inline-image");

    /* If the expanded image has more than one image to choose from, clicking it will
     * temporarily show the next image.  Only show a pointer cursor if this is available. */
    if(data.images.length > 1)
      viewer_img.addClassName("clickable");

    viewer_img.observe("mousedown", function(e) {
      if(e.button != 0)
        return;

      data.toggled_from = data.current;
      var idx = (data.current + 1) % data.images.length;
      InlineImage.show_image_no(data.html_id, idx);
      InlineImage.mouse_down = data;

      /* We need to stop the event, so dragging the mouse after clicking won't turn it
       * into a drag in Firefox.  If that happens, we won't get the mouseup. */
      e.stop();
    });
  },

  init: function()
  {
    /* Mouseup events aren't necessarily sent to the same element that received the mousedown,
     * so we need to track which element received a mousedown and handle mouseup globally. */
    document.observe("mouseup", function(e) {
      if(e.button != 0)
        return;
      if(InlineImage.mouse_down == null)
        return;
      e.stop();
      var data = InlineImage.mouse_down;
      InlineImage.mouse_down = null;

      InlineImage.show_image_no(data.html_id, data.toggled_from);
      data.toggled_from = null;
    });

  },

  expand: function(id)
  {
    var container = $(id);
    var data = container.inline_image;
    data.expanded = true;

    if(!data.initted)
    {
      data.initted = true;
      var images = data["images"];

      var img_html = "";
      for(var idx = 0; idx < data.images.length; ++idx)
      {
        var image = images[idx];
        var width, height, src;
        if(image["sample_width"])
        {
          src = image["sample_url"];
        } else {
          src = image["file_url"];
        }

        var img_id = data.html_id + "-img-" + idx;
        img_html += "<img src='" + src + "' id='" + img_id + "' width=" + width + " height=" + height + " style='display: none;'>";
      }

      var viewer_img = container.down(".main-inline-image");
      viewer_img.innerHTML = img_html;
    }

    container.down(".inline-thumb").hide();
    InlineImage.show_image_no(data.html_id, 0);
    container.down(".expanded-image").show();

    // container.down(".expanded-image").scrollIntoView();
  },

  close: function(id)
  {
    var container = $(id);
    var data = container.inline_image;
    data.expanded = false;
    container.down(".expanded-image").hide();
    container.down(".inline-thumb").show();
  },

  show_image_no: function(id, idx)
  {
    var container = $(id);
    var data = container.inline_image;
    var images = data["images"];
    var image = images[idx];
    var zoom = InlineImage.get_zoom(data.zoom_level);

    /* We need to set innerHTML rather than just setting attributes, so the changes happen
     * atomically.  Otherwise, Firefox will apply the width and height changes before source,
     * and flicker the old image at the new image's dimensions. */
    var width, height;
    if(image["sample_width"])
    {
      width = image["sample_width"] * zoom;
      height = image["sample_height"] * zoom;
    } else {
      width = image["width"] * zoom;
      height = image["height"] * zoom;
    }
      width = width.toFixed(0);
      height = height.toFixed(0);

    if(data.current != idx)
    {
      var old_img_id = data.html_id + "-img-" + data.current;
      var old_img = $(old_img_id);
      if(old_img)
        old_img.hide();
    }

    var img_id = data.html_id + "-img-" + idx;
    var img = $(img_id);
    if(img)
    {
      img.width = width;
      img.height = height;
      img.show();
    }

    if(data.current != idx)
    {
      var new_button = $(data.html_id + "-" + idx);
      if(new_button)
        new_button.addClassName("selected-image-tab");

      var old_button = $(data.html_id + "-" + data.current);
      if(old_button)
        old_button.removeClassName("selected-image-tab");

      data.current = idx;
    }
  },

  zoom: function(id, dir)
  {
    var container = $(id);
    var data = container.inline_image;
    if(dir == 0)
      data.zoom_level = 0; // reset
    else
      data.zoom_level += dir;

    if(data.zoom_level > InlineImage.zoom_levels.length - 1)
      data.zoom_level = InlineImage.zoom_levels.length - 1;
    if(data.zoom_level < -InlineImage.zoom_levels.length + 1)
      data.zoom_level = -InlineImage.zoom_levels.length + 1;

    /* Update the zoom level. */
    var zoom_id = data.html_id + "-zoom";
    var zoom = InlineImage.get_zoom(data.zoom_level) * 100;
    $(zoom_id).update(zoom.toFixed(0) + "%");

    InlineImage.show_image_no(id, data.current);
  }

}
