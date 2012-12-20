var align_element_to_menu = function(submenu, menu_item_elem)
{
  /* Align the top of the dropdown to the bottom-left of the menu link. */
  var offset = menu_item_elem.cumulativeOffset();
  var left = offset.left - 3;

  {
    /* If this would result in the menu falling off the right side of the screen,
     * push it left. */
    var right_edge = submenu.offsetWidth + offset.left;
    var right_overlap = right_edge - document.body.offsetWidth;
    if(right_overlap > 0)
      left -= right_overlap;
  }

  submenu.style.left = left + "px";

  /* offset.top is the top of the menu item text. */
  var bottom = offset.top;

  /* We want to align to the bottom, not the top, so add the height of the text. */
  if(menu_item_elem.getBoundingClientRect)
  {
    /* This is needed in Chrome, where the scrollHeight of our text item is always 0. */
    var height = menu_item_elem.getBoundingClientRect().bottom - menu_item_elem.getBoundingClientRect().top;
    bottom += height;
  }
  else
  {
    bottom += menu_item_elem.scrollHeight;
  }
  submenu.style.top = bottom + "px";
}

function MainMenu(container, def)
{
  this.container = container;
  this.def = def;
  this.submenu = null;
  this.shown_def = null;
  this.focused_menu_item = null;
  this.dropdownTimer = null;
  this.dragging = null;
  this.dragging_over = null;

  this.document_mouseup_event = this.document_mouseup.bindAsEventListener(this);
  this.document_click_event = this.document_click.bindAsEventListener(this);
  this.mousemove_during_dropdown_timer_event = this.mousemove_during_dropdown_timer.bindAsEventListener(this);
}

MainMenu.prototype.get_elem_for_top_item = function(item)
{
    return this.container.down(".top-item-" + item.name);
}

/* This must be called to initialize the menus. */
MainMenu.prototype.init = function()
{
  for(var i = 0; i < this.def.length; ++i)
  {
    var item = this.def[i];
    var elem = this.get_elem_for_top_item(item);

    /* Remove any empty submenus. */
    if(item.sub && !item.sub.length)
      item.sub = null;

    /* The submenu, if open, is a child of elem.  Bind these events to the top
     * menu link, not to elem.  (We don't really need to do this anymore, but
     * it doesn't hurt.) */
    var a = elem.down("a");

    /* Implement the dropdown timer.  Start counting when the mouse goes down, and stop if
     * the mouse comes up for any reason.  This prevents the dropdown from flickering open
     * every time a top-level link is clicked. */
    a.observe("mousedown", this.top_menu_mousedown.bindAsEventListener(this, item));
    a.observe("click", this.top_menu_click.bindAsEventListener(this));
    a.observe("mouseover", this.top_menu_mousedown.bindAsEventListener(this, item));
    a.observe("touchstart", this.top_menu_mousedown.bindAsEventListener(this, item));

    /* IE8 needs this one to prevent dragging: */
    a.observe("dragstart", function(event) { event.stop(); }.bindAsEventListener(this));
  }

  var bound_remove_submenu = this.remove_submenu.bindAsEventListener(this);
  Element.observe(window, "blur", bound_remove_submenu);
  Element.observe(window, "pageshow", bound_remove_submenu);
  Element.observe(window, "pagehide", bound_remove_submenu);

  document.observe("mouseover", function (e) {
    var elt = e.findElement('.submenu, .menu, .dropdown-menu');
    if (!elt) bound_remove_submenu();
    return false;
  });
}

MainMenu.prototype.get_submenu = function(name)
{
  for(var i = 0; i < this.def.length; ++i)
  {
    if(this.def[i].name == name)
      return this.def[i];
  }
  return null;
}

MainMenu.prototype.show_submenu = function(parent_menu_element, def)
{
  if(this.shown_def == def)
    return;
  this.remove_submenu();

  if(!def.sub)
  {
    this.shown_def = def;
    return;
  }

  var menu_item_elem = this.get_elem_for_top_item(def);
  menu_item_elem.addClassName("selected-menu");

  this.shown_def = def;

  /* Create the dropdown menu. */
  var html = "";
  var id = "";
  if(def.html_id)
    id = 'id="' + def.html_id + '" ';
  html += "<div " + id + "class='dropdown-menu'>";

  for(var i = 0; i < def.sub.length; ++i)
  {
    var item = def.sub[i];

    /* IE8 acts funny if we test item.separator directly when it's undefined. */
    if(item.separator == true)
    {
      html += '<div class="separator"></div>';
      continue;
    }

    var class_names = "submenu";
    class_names += " submenu-item-" + i;
    if(item.class_names)
      class_names += " " + item.class_names.join(" ");


    html += "<a class='" + class_names + "' href=\"" + (item.dest || "#") + "\">";
    html += item.label.replace(" ", "&nbsp;", "g");
    html += "</a>";
  }
  html += "</div>";

  /* Create the menu. */
  this.submenu = document.createElement("div");
  /* Note that we should be positioning relative to the viewport; our relative parent
   * should be document.body.  However, don't parent our submenu directly to the body,
   * since that breaks on some pages in IE8. */
  this.container.insertBefore(this.submenu, this.container.firstChild);
  $(this.submenu).replace(html);
  this.submenu = this.container.down(".dropdown-menu");

  align_element_to_menu(this.submenu, menu_item_elem);

  var bound_remove_submenu = this.remove_submenu.bind(this);
  var menu_item_mouseover_event = function(event) {
    this.hovering_over_item(event.target);
  }.bindAsEventListener(this);

  var menu_item_mouseout_event = function(event) {
    this.hovering_over_item(null);
  }.bindAsEventListener(this);

  /* Bind events to the new submenu. */
  for(var i = 0; i < def.sub.length; ++i)
  {
    var elem = this.submenu.down(".submenu-item-" + i);
    if(!elem)
      continue;

    var item = def.sub[i];
    if(item.func)
    {
      elem.observe("click", function(event, item)
      {
        event.stop();
        this.func_modal = item.func(event, this, def, item);
      }.bindAsEventListener(this, item));
    }

    /* If this menu item requires a login, attach the login handler. */
    if(item.login)
      elem.observe("click", User.run_login_onclick);

    /* Keep track of which menu item we're hovering over. */
    elem.observe("mouseover", menu_item_mouseover_event);
    elem.observe("mouseout", menu_item_mouseout_event);
  }
}

MainMenu.prototype.remove_submenu = function()
{
  if(this.submenu)
  {
    this.submenu.parentNode.removeChild(this.submenu);
    this.submenu = null;
  }

  if(this.shown_def)
  {
    var menu_item_elem = this.get_elem_for_top_item(this.shown_def);
    menu_item_elem.removeClassName("selected-menu");
    this.shown_def = null;
  }
  if (this.func_modal && this.func_modal.hide) {
    this.func_modal.hide();
  }
}

MainMenu.prototype.stop_dropdown_timer = function()
{
  if(!this.dropdownTimer)
    return;

  clearTimeout(this.dropdownTimer);
  this.dropdownTimer = null;

  document.stopObserving("mousemove", this.mousemove_during_dropdown_timer_event);
}

MainMenu.prototype.hovering_over_item = function(element)
{
  if(this.focused_menu_item)
    this.focused_menu_item.removeClassName("focused-menu-item");

  /* Keep track of which menu item we're hovering over. */
  this.focused_menu_item = element;

  /* Mark the hovered item.  For some reason, :hover CSS rules don't work while
   * a mouse button is depressed in WebKit. */
  if(element)
    element.addClassName("focused-menu-item");
}

/* Stop the drag, either because the mouse button was released or some other
 * event cancelled it.  Close the menu and clean up. */
MainMenu.prototype.stop_drag = function()
{
  if(!this.dragging)
    return;
  this.dragging = null;
  this.dragging_over = null;
  this.hovering_over_item(null);

  document.stopObserving("mouseup", this.document_mouseup_event);
  document.stopObserving("click", this.document_click_event);

  this.stop_dropdown_timer();
  this.remove_submenu();
};

MainMenu.prototype.top_menu_mousedown = function(event, def)
{
  // preventDefault here will stop the mousedown from starting a drag, which will cancel
  // the click in mouse browsers and do other things we don't want.  Don't use stop();
  // if we call stopPropagation we'll also stop clicks.
  event.preventDefault();

  /* Stop the previous drag event, which probably shouldn't still be active. */
  this.stop_drag();

  document.observe("mouseup", this.document_mouseup_event);
  document.observe("click", this.document_click_event);

  this.dragging = [event.clientX, event.clientY];
  this.dragging_over = def;

  /* Start the timer before we show the dropdown automatically, and set up the
   * mousemove event to show the dropdown immediately if we're dragged before that
   * happens. */
  document.observe("mousemove", this.mousemove_during_dropdown_timer_event);
  this.dropdownTimer = window.setTimeout(function()
  {
    if(this.dragging_over)
      this.show_submenu(event.target, this.dragging_over);
  }.bind(this), 250);
}

/*
 * We received a click while the mouse was already held down.  This probably means the
 * user right- or middle-clicked a menu item while holding the menu open with the left
 * mouse button.  In this case, let the browser do whatever it's going to do (probably
 * open the menu item in a new window), and simply close the menu so releasing the left
 * button doesn't activate the item a second time.
 *
 * Ordinary menu selections are handled in document_mouseup.
 */
MainMenu.prototype.document_click = function(event)
{
  if(event.isLeftClick())
    return;
  this.stop_drag();
}

MainMenu.prototype.document_mouseup = function(event)
{
  if(!event.isLeftClick())
  {
    /* The user right- or middle-clicked, so we need to close the menu.  We can't
     * do this from onclick, since WebKit doesn't yet send onclick for non-primary
     * buttons.  However, we can't actually remove the menu right now, since that'll
     * cause Gecko to never send the click.  Defer it, so the menu will be closed
     * after the click event finishes. */
    this.stop_drag.bind(this).defer();
    return;
  }

  if(this.dropdownTimer)
  {
    clearTimeout(this.dropdownTimer);
    this.dropdownTimer = null;
  }

  var menu_was_shown = this.shown_def;
  var hovered_menu_item = this.focused_menu_item;
  this.stop_drag();
  if(!menu_was_shown)
    return;

  /* We'll only get this event if the menu was opened.  Prevent the click from
   * occuring if the menu was opened.  Just stopping the event won't do it. */
  event.stop();
  this.cancel_next_click = true;

  /* Tricky: we can't be absolutely certain that this mouseup will result in a
   * click event.  Clear cancel_next_click if the event doesn't arrive. */
  (function() { this.cancel_next_click = false; }.bind(this)).defer();

  if(!hovered_menu_item)
    return;

  /* Simulate a click, so JS anchors work properly. */
  if(document.createEvent)
  {
    var ev = document.createEvent("MouseEvents");
    ev.initMouseEvent("click", true, true, document.defaultView, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
    if(hovered_menu_item.dispatchEvent(ev) && !ev.stopped)
      window.location.href = hovered_menu_item.href;
  }
  else
  {
    /* IE.  Don't use hovered_menu_item.click(); it won't work in IE7. */
    if(hovered_menu_item.fireEvent("onclick"))
      window.location.href = hovered_menu_item.href;
  }
};

MainMenu.prototype.mousemove_during_dropdown_timer = function(event)
{
  event.returnValue = false;
  event.preventDefault();

  if(!this.dropdownTimer)
    return;

  /* If we've dragged downward before the menu is shown, show it. */
  if(event.clientY - this.dragging[1] < 3)
    return;

  /* Dragging opens the dropdown immediately, so stop the dropdown timer if
   * it's running. */
  this.stop_dropdown_timer();

  this.show_submenu(event.target, this.dragging_over);
};

MainMenu.prototype.top_menu_click = function(event)
{
  this.stop_drag();

  if(this.cancel_next_click)
  {
    /* If a click arrives after the dropdown menu was opened, ignore it.  Note that by
     * the time we get here, the dropdown menu will usually have already been closed by
     * mouseup, so we can't just check this.shown_def. */
    this.cancel_next_click = false;
    event.stop();
  }
}

MainMenu.prototype.top_menu_mouseover = function(event, def)
{
  if(this.dragging)
  {
    /* We're dragging, and the mouse moved from one menu item to another before
     * the item was displayed.  Update, so we show the new item. */
    this.dragging_over = def;
  }

  /* If we hover over a top-level menu item while the dropdown is open,
   * show the new menu. */
  if(!this.shown_def)
    return;
  this.show_submenu(event.target, def);
}

MainMenu.prototype.add_forum_posts_to_submenu = function()
{
  var menu = this.get_submenu("forum").sub;
  if(!menu)
    return;

  var forum_posts = Cookie.get("current_forum_posts");
  if(!forum_posts)
    return;
  var forum_posts = forum_posts.evalJSON();
  if(!forum_posts.length)
    return;

  var any_unread = false;
  for(var i = 0; i < forum_posts.length; ++i)
    if(forum_posts[i][2])
      any_unread = true;
  if(any_unread)
    menu.push({ label: "Mark&nbsp;all&nbsp;read", func: Forum.mark_all_read });

  menu.push({ separator: true });

  for(var i = 0; i < forum_posts.length; ++i)
  {
    /* [title, id, unread, last_page_no] */
    var fp = forum_posts[i];
    var dest = "/forum/show/" + fp[1];
    if(parseInt(fp[3]) > "1")
	    dest += "?page=" + fp[3];
    menu.push({
      label: fp[0], dest: dest, class_names: ["forum-topic"]
    });

    /* Bold the item if it's unread. */
    if(fp[2])
      menu[menu.length-1].class_names.push("unread-topic");
  }
}

MainMenu.prototype.mark_forum_posts_read = function()
{
  var menu = this.get_submenu("forum").sub;
  if(!menu)
    return;

  for(var i = 0; i < menu.length; ++i)
  {
    if(!menu[i].class_names)
      continue;
    menu[i].class_names = menu[i].class_names.reject(function(x) { return x == "unread-topic"; });
  }
}

/* This shows a popup search box, contained within container like a submenu, aligned
 * to the specified element (normally a menu item).  The popup will destroy itself when
 * finished. */
function QuickSearch(container, html, align_to)
{
  html = "<div class='dropdown-menu'>" + html + "</div>";

  this.container = container;

  this.hide_event = this.hide_event.bindAsEventListener(this);
  this.on_document_keydown_event = this.on_document_keydown_event.bindAsEventListener(this);
  this.document_mousedown_event = this.document_mousedown_event.bindAsEventListener(this);

  /* Create the contents. */
  this.submenu = document.createElement("div");

  /* Note that we should be positioning relative to the viewport; our relative parent
   * should be document.body.  However, don't parent our submenu directly to the body,
   * since that breaks on some pages in IE8. */
  this.container.insertBefore(this.submenu, this.container.firstChild);
  $(this.submenu).replace(html);
  this.submenu = this.container.down(".dropdown-menu");

  align_element_to_menu(this.submenu, align_to);

  /* We watch for escape presses on the document instead of the element, so even if
   * the element doesn't receive focus for some reason, pressing escape still closes
   * it. */
  document.observe("keydown", this.on_document_keydown_event);
  document.observe("mousedown", this.document_mousedown_event);

  Element.observe(window, "pageshow", this.hide_event);
  Element.observe(window, "pagehide", this.hide_event);

  /* This stuff is specific to the actual content of the box: focus the form, and
   * hide it on submit. */
  this.submenu.down(".default").focus();
  this.submenu.select("form").each(function(e) {
    e.observe("submit", this.hide_event);
  }.bind(this));
}

QuickSearch.prototype.on_document_keydown_event = function(event) {
  if (event.keyCode == Event.KEY_ESC)
    this.hide();
}

QuickSearch.prototype.document_mousedown_event = function(event)
{
  if($(event.target).isParentNode(this.submenu))
    return;
  this.hide();
}

QuickSearch.prototype.hide_event = function(event)
{
  this.hide();
};

QuickSearch.prototype.hide = function()
{
  if(!this.submenu)
    return;

  /* Remove the menu from the document.  We need to work around a FF3.6 bug here: if
   * we simply remove the item from the document while a form dropdown box is open,
   * the dropdown won't disappear.  We need to hide() first to cause it to be dropped,
   * and defer removing the element until after we return in order to let it take
   * effect. */
  this.submenu.hide();
  (function(elem) {
    elem.parentNode.removeChild(elem);
  }).curry(this.submenu).defer();

  this.submenu = null;
  document.stopObserving("keydown", this.on_document_keydown_event);
  document.stopObserving("mousedown", this.document_mousedown_event);
  Element.stopObserving(window, "blur", this.hide_event);
  Element.stopObserving(window, "pageshow", this.hide_event);
  Element.stopObserving(window, "pagehide", this.hide_event);
}

/* Create functions that can be used as the func parameter to a menu item to
 * open quick searches. */
function MakeSearchHandler(search_path, id, submit_button_text)
{
  var ShowSearch = function(event, menu, def, item)
  {
    var html = "";
    html += '<form action="' + search_path + '" method="get">';
    html += '<input id="' + id + '" name="' + id + '" size="30" type="text" class="default">';
    html += '<br>';
    html += '<input style="margin-top: 0.25em;" type="submit" value="' + submit_button_text + '">';
    html += '</form>';

    return new QuickSearch(menu.container, html, menu.get_elem_for_top_item(def));
  }
  return ShowSearch;
}

ShowPostSearch = MakeSearchHandler("/post", "tags", "Search posts");
ShowCommentSearch = MakeSearchHandler("/comment/search", "query", "Search comments");
ShowNoteSearch = MakeSearchHandler("/note/search", "query", "Search notes");
ShowArtistSearch = MakeSearchHandler("/artist", "name", "Search artists");
ShowTagSearch = MakeSearchHandler("/tag", "name", "Search tags");
ShowPoolSearch = MakeSearchHandler("/pool", "query", "Search pools");
ShowWikiSearch = MakeSearchHandler("/wiki", "query", "Search wiki");
ShowForumSearch = MakeSearchHandler("/forum/search", "query", "Search forums");

