window.History = {
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
        History.last_click = -1
      }

      History.mouse_is_down();
      event.stopPropagation();
      event.preventDefault();
    }, true)
    History.update()
  },

  /* change_id is the display column. XXX no */
  add_change: function(change_id, group_by_type, group_by_id, ids, user_id) {
    History.checked.push({
      id: change_id,
      ids: ids,
      group_by_type: group_by_type,
      group_by_id: group_by_id,
      user_id: user_id,
      on: false,
      row: $("r" + change_id)
    })
    $("r" + change_id).observe("mousedown", function(e) { History.mousedown(change_id, e), true })
    $("r" + change_id).observe("mouseover", function(e) { History.mouseover(change_id, e), true })
    if($("r" + change_id).down(".id"))
      $("r" + change_id).down(".id").observe("click", function(event) { History.id_click(change_id) });
    $("r" + change_id).down(".author").observe("click", function(event) { History.author_click(change_id) });
    $("r" + change_id).down(".change").observe("click", function(event) { History.change_click(change_id) });
  },

  update: function() {
    // Set selected flags on selected rows, and remove them from unselected rows.
    for (var i = 0; i < History.checked.length; ++i) {
      var row = History.checked[i].row

      if(History.checked[i].on) {
        row.addClassName("selected");
      } else {
        row.removeClassName("selected");
      }
    }

    if (History.count_selected() > 0) {
      $("undo").removeClassName("footer-disabled");
      $("redo").removeClassName("footer-disabled");
    } else {
      $("undo").addClassName("footer-disabled");
      $("redo").addClassName("footer-disabled");
    }
  },

  id_click: function(id, event) {
    id = History.get_row_by_id(id);
    $("search").value = History.checked[id].group_by_type.toLowerCase() + ":" + History.checked[id].group_by_id
  },

  author_click: function(id, event) {
    id = History.get_row_by_id(id);
    $("search").value = "user:" + History.checked[id].user_id
  },

  change_click: function(id, event) {
    id = History.get_row_by_id(id);
    $("search").value = "change:" + History.checked[id].id
  },

  // Return the number of selected items.
  count_selected: function() {
    var ret = 0
    for (var i = 0; i < History.checked.length; ++i) {
      if (History.checked[i].on)
        ++ret
    }
    return ret;
  },

  // Get the index of the first selected item.
  get_first_selected_row: function() {
    for (var i = 0; i < History.checked.length; ++i) {
      if (History.checked[i].on)
        return i;
    }
    return null;
  },

  // Get the index of the item with the specified id.
  get_row_by_id: function(id) {
    for (var i = 0; i < History.checked.length; ++i) {
      if (History.checked[i].id.toString() === id.toString())
        return i;
    }
    return -1;
  },

  // Set [first, last] = on.
  set: function(first, last, isOn) {
    var i = first;
    while(true)
    {
      History.checked[i].on = isOn;

      if(i.toString() === last.toString())
        break;

      i += (last > first)? +1:-1;
    }
  },

  doc_mouseup: function(event) {
    History.dragging = false
    document.stopObserving("mouseup", History.doc_mouseup)
  },

  // The mouse is down, so we're dragging; watch mouseup to know when we've let go.
  mouse_is_down: function() {
    History.dragging = true;
    document.observe("mouseup", History.doc_mouseup)
  },

  mousedown: function(id, event) {
    if (!Event.isLeftClick(event)) {
      return;
    }

    History.mouse_is_down()

    var i = History.get_row_by_id(id)
    if (i === -1) {
      return;
    }

    var first = null
    var last = null
    if (History.last_click !== -1 && event.shiftKey) {
      first = History.last_click
      last = i
    } else {
      first = last = History.last_click = i
      History.checked[i].on = !History.checked[i].on;
    }

    var isOn = History.checked[first].on

    if (!event.ctrlKey) {
      History.set(0, History.checked.length-1, false)
    }
    History.set(first, last, isOn)
    History.update()

    event.stopPropagation();
    event.preventDefault();
  },

  mouseover: function(id, event) {
    var i = History.get_row_by_id(id)
    if (i===-1) return;

    if (History.last_click === -1) {
      History.last_click = i
    }

    if (!History.dragging) {
      return;
    }

    History.set(0, History.checked.length-1, false)

    var first = History.last_click
    var last = i
    var this_click = i

    History.set(first, last, true)
    History.update()
  },

  undo: function(redo) {
    if (History.count_selected() === 0) {
      return;
    }
    var list = []
    for (var i = 0; i < History.checked.length; ++i) {
      if (!History.checked[i].on)
        continue;
      list = list.concat(History.checked[i].ids)
    }

    if(redo)
      notice("Reapplying...");
    else
      notice("Undoing...");

    new Ajax.Request("/history/undo.json", {
      requestHeaders: {
        "X-CSRF-Token": jQuery("meta[name=csrf-token]").attr("content")
      },
      parameters: {
        "id": list.join(","),
        "redo": redo? 1:0
      },

      onComplete: function(resp) {
        resp = resp.responseJSON

        if (resp.success) {
          var text = resp.errors;
          if(resp.successful > 0)
            text.unshift(redo? "Changes reapplied.":"Changes undone.");
          notice(text.join("<br>"));
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  }
}
