PostTagHistory = {
  last_click: -1,
  checked: [],
  dragging: false,

  init: function() {
    // Watch mousedown events on the table itself, so clicking between table rows and dragging
    // doesn't misbehave.
    $("history").observe("mousedown", function(event) {
      if (!event.shiftKey) {
        // Clear last_click, so dragging will extend from the next position crossed instead of
        // the previous position clicked.
        PostTagHistory.last_click = -1
      }

      PostTagHistory.mouse_is_down();
      event.stopPropagation();
      event.preventDefault();
    }, true)
    PostTagHistory.update()
  },

  add_change: function(id, post_id, user_id) {
    PostTagHistory.checked.push({
      id: id,
      post_id: post_id,
      user_id: user_id,
      on: false,
      row: $("r" + id)
    })
    $("r" + id).observe("mousedown", function(e) { PostTagHistory.mousedown(id, e), true })
    $("r" + id).observe("mouseover", function(e) { PostTagHistory.mouseover(id, e), true })
  },

  update: function() {
    // Set selected flags on selected rows, and remove them from unselected rows.
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      var row = PostTagHistory.checked[i].row

      if(PostTagHistory.checked[i].on) {
        row.addClassName("selected");
      } else {
        row.removeClassName("selected");
      }
    }

    if (PostTagHistory.count_selected() > 0) {
      $("undo").className = ""
    } else {
      $("undo").className = "footer-disabled"
    }

    if (PostTagHistory.count_selected() == 1) {
      i = PostTagHistory.get_first_selected_row()
      $("revert").href = "post_tag_history/revert?id=" + PostTagHistory.checked[i].id
      $("revert").className = ""
      $("post_id").value = PostTagHistory.checked[i].post_id
      $("user_name").value = PostTagHistory.checked[i].user_id
    } else {
      $("revert").href = "#"
      $("revert").className = "footer-disabled"
    }
  },

  // Return the number of selected items.
  count_selected: function() {
    ret = 0
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (PostTagHistory.checked[i].on)
        ++ret
    }
    return ret;
  },

  // Get the index of the first selected item.
  get_first_selected_row: function() {
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (PostTagHistory.checked[i].on)
        return i;
    }
    return null;
  },

  // Get the index of the item with the specified id.
  get_row_by_id: function(id) {
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (PostTagHistory.checked[i].id == id)
        return i;
    }
    return null;
  },

  // Set [first, last] = on.
  set: function(first, last, isOn) {
    i = first;
    while(true)
    {
      PostTagHistory.checked[i].on = isOn;

      if(i == last)
        break;

      i += (last > first)? +1:-1;
    }
  },

  doc_mouseup: function(event) {
    PostTagHistory.dragging = false
    document.stopObserving("mouseup", PostTagHistory.doc_mouseup)
  },

  // The mouse is down, so we're dragging; watch mouseup to know when we've let go.
  mouse_is_down: function() {
    PostTagHistory.dragging = true;
    document.observe("mouseup", PostTagHistory.doc_mouseup)
  },

  mousedown: function(id, event) {
    if (!Event.isLeftClick(event)) {
      return;
    }

    PostTagHistory.mouse_is_down()

    var i = PostTagHistory.get_row_by_id(id)
    if (i == null) {
      return;
    }

    var first = null
    var last = null
    if (PostTagHistory.last_click != -1 && event.shiftKey) {
      first = PostTagHistory.last_click
      last = i
    } else {
      first = last = PostTagHistory.last_click = i
      PostTagHistory.checked[i].on = !PostTagHistory.checked[i].on;
    }

    var isOn = PostTagHistory.checked[first].on

    if (!event.ctrlKey) {
      PostTagHistory.set(0, PostTagHistory.checked.length-1, false)
    }
    PostTagHistory.set(first, last, isOn)
    PostTagHistory.update()

    event.stopPropagation();
    event.preventDefault();
  },

  mouseover: function(id, event) {
    var i = PostTagHistory.get_row_by_id(id)
    if (!i) return;

    if (PostTagHistory.last_click == -1) {
      PostTagHistory.last_click = i
    }

    if (!PostTagHistory.dragging) {
      return;
    }

    PostTagHistory.set(0, PostTagHistory.checked.length-1, false)

    first = PostTagHistory.last_click
    last = i
    this_click = i

    PostTagHistory.set(first, last, true)
    PostTagHistory.update()
  },

  undo: function() {
    if (PostTagHistory.count_selected() == 0) {
      return;
    }
    var list = []
    for (i = 0; i < PostTagHistory.checked.length; ++i) {
      if (!PostTagHistory.checked[i].on)
        continue;
      list.push(PostTagHistory.checked[i].id)
    }

    notice("Undoing...");

    new Ajax.Request("/post_tag_history/undo.json", {
      parameters: {
        "id": list.join(",")
      },

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          notice("Changes undone.");
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  }
}
