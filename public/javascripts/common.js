var DANBOORU_VERSION = {
  major: 1,
  minor: 13,
  build: 0
}

/* If initial is true, this is a notice set by the notice cookie and not a
 * realtime notice from user interaction. */
function notice(msg, initial) {
  /* If this is an initial notice, and this screen has a dedicated notice
   * container other than the floating notice, use that and don't disappear
   * it. */
  if(initial) {
    var static_notice = $("static_notice");
    if(static_notice) {
      static_notice.update(msg);
      static_notice.show();
      return;
    }
  }

  start_notice_timer();
  $('notice').update(msg);
  $('notice-container').show();
}

function number_to_human_size(size, precision)
{
  if(precision == null)
    precision = 1;

  size = Number(size);
  if(size.toFixed(0) == 1) text = "1 Byte";
  else if(size < 1024)                  text = size.toFixed(0) + " Bytes";
  else if(size < 1024*1024)             text = (size / 1024).toFixed(precision) + " KB";
  else if(size < 1024*1024*1024)        text = (size / (1024*1024)).toFixed(precision) + " MB";
  else if(size < 1024*1024*1024*1024)   text = (size / (1024*1024*1024)).toFixed(precision) + " GB";
  else                                  text = (size / (1024*1024*1024*1024)).toFixed(precision) + " TB";

  text = text.gsub(/([0-9]\.\d*?)0+ /, '#{1} ' ).gsub(/\. /,' ');
  return text;
}

var ClearNoticeTimer;
function start_notice_timer() {
  if(ClearNoticeTimer)
    window.clearTimeout(ClearNoticeTimer);

  ClearNoticeTimer = window.setTimeout(function() {
		  $('notice-container').hide();
  }, 5000);
}

var ClipRange = Class.create({
  initialize: function(min, max) {
    if (min > max)  {
      throw "paramError"
    }

    this.min = min
    this.max = max
  },

  clip: function(x) {
    if (x < this.min) {
      return this.min
    }
    
    if (x > this.max) {
      return this.max
    }
    
    return x
  }
})

Object.extend(Element, {
  appendChildBase: Element.appendChild,
  appendChild: function(e) {
    this.appendChildBase(e)
    return e
  }
});

Object.extend(Element.Methods, {
  showBase: Element.show,
  show: function(element, visible) {
    if (visible || visible == null)
      return $(element).showBase();
    else
      return $(element).hide();
  },
  setClassName: function(element, className, enabled) {
    if(enabled)
      return $(element).addClassName(className);
    else
      return $(element).removeClassName(className);
  },
  pickClassName: function(element, classNameEnabled, classNameDisabled, enabled) {
    $(element).setClassName(classNameEnabled, enabled);
    $(element).setClassName(classNameDisabled, !enabled);
  },
  isParentNode: function(element, parentNode) {
    while(element) {
      if(element == parentNode)
        return true;
      element = element.parentNode;
    }
    return false;
  },
  setTextContent: function(element, text)
  {
    if(element.innerText)
      element.innerText = text;
    else
      element.textContent = text;
    return element;
  }
});
Element.addMethods()

var KeysDown = new Hash();

/* Many browsers eat keyup events if focus is lost while the button
 * is pressed. */
document.observe("blur", function(e) { KeysDown = new Hash(); })

function OnKeyCharCode(key, f, element)
{
  if(window.opera)
    return;
  if(!element)
    element = document;
  element.observe("keyup", function(e) {
    if (e.keyCode != key)
      return;
    KeysDown.set(KeysDown[e.keyCode], false);
  });
  element.observe("keypress", function(e) {
    if (e.charCode != key)
      return;
    if (e.shiftKey || e.altKey || e.ctrlKey || e.metaKey)
      return;
    if(KeysDown.get(KeysDown[e.keyCode]))
      return;
    KeysDown.set(KeysDown[e.keyCode], true);

    var target = e.target;
    if(target.tagName == "INPUT" || target.tagName == "TEXTAREA")
      return;

    f(e);
    e.stop();
    e.preventDefault();
  });
}

function OnKey(key, options, press, release)
{
  if(!options)
    options = {};
  var element = options["Element"]
  if(!element)
    element = document;
  if(element == document && window.opera && !options.AlwaysAllowOpera)
    return;

  element.observe("keyup", function(e) {
    if (e.keyCode != key)
      return;
    KeysDown[e.keyCode] = false
    if(release)
      release(e);
  });

  element.observe("keydown", function(e) {
    if (e.keyCode != key)
      return;
    if (e.metaKey)
      return;
    if (e.shiftKey != !!options.shiftKey)
      return;
    if (e.altKey != !!options.altKey)
      return;
    if (e.ctrlKey != !!options.ctrlKey)
      return;
    if (!options.allowRepeat && KeysDown[e.keyCode])
      return;

    KeysDown[e.keyCode] = true
    var target = e.target;
    if(!options.AllowTextAreaFields && target.tagName == "TEXTAREA")
      return;
    if(!options.AllowInputFields && target.tagName == "INPUT")
      return;

    if(press && !press(e))
      return;
    e.stop();
    e.preventDefault();
  });
}

function InitTextAreas()
{
  $$("TEXTAREA").each(function(elem) {
    var form = elem.up("FORM");
    if(!form)
      return;

    if(elem.set_login_handler)
      return;
    elem.set_login_handler = true;

    OnKey(13, { ctrlKey: true, AllowInputFields: true, AllowTextAreaFields: true, Element: elem}, function(f) {
      $(form).submitWithLogin();
    });
  });
}

function InitAdvancedEditing()
{
  if(Cookie.get("show_advanced_editing") != "1")
    return;

  $(document.documentElement).removeClassName("hide-advanced-editing");
}

/* When we resume a user submit after logging in, we want to run submit events, as
 * if the submit had happened normally again, but submit() doesn't do this.  Run
 * a submit event manually. */
Element.addMethods("FORM", {
  simulate_submit: function(form)
  {
    form = $(form);

    if(document.createEvent)
    {
      var e = document.createEvent("HTMLEvents");
      e.initEvent("submit", true, true);
      form.dispatchEvent(e);

      if(!e.stopped)
        form.submit();
    }
    else
    {
      if(form.fireEvent("onsubmit"))
        form.submit();
    }
  }
});


Element.addMethods({
  simulate_anchor_click: function(a, ev)
  {
    a = $(a);

    if(document.dispatchEvent)
    {
      if(a.dispatchEvent(ev) && !ev.stopped)
        window.location.href = a.href;
    }
    else
    {
      if(a.fireEvent("onclick", ev))
        window.location.href = a.href;
    }
  }
});


clone_event = function(orig)
{
  if(document.dispatchEvent)
  {
    var e = document.createEvent("MouseEvent");
    e.initMouseEvent(orig.type, orig.canBubble, orig.cancelable, orig.view,
        orig.detail, orig.screenX, orig.screenY, orig.clientX, orig.clientY,
        orig.ctrlKey, orig.altKey, orig.shiftKey, orig.metaKey,
        orig.button, orig.relatedTarget);
    return Event.extend(e);
  }
  else
  {
    var e = document.createEventObject(orig);
    return Event.extend(e);
  }
}

Object.extend(String.prototype, {
  subst: function(subs) {
    var text = this;
    for(var s in subs)
    {
      var r = new RegExp("\\${" + s + "}", "g");
      var to = subs[s];
      if(to == null) to = "";
      text = text.replace(r, to);
    }

    return text;
  }
});

function createElement(type, className, html)
{
  var element = $(document.createElement(type));
  element.className = className;
  element.innerHTML = html;
  return element;
}

/* Prototype calls onSuccess instead of onFailure when the user cancelled the AJAX
 * request.  Fix that with a monkey patch, so we don't have to track changes inside
 * prototype.js. */
Ajax.Request.prototype.successBase = Ajax.Request.prototype.success;
Ajax.Request.prototype.success = function()
{
  try {
    if(this.transport.getAllResponseHeaders() == null)
      return false;
  } catch (e) {
    /* FF throws an exception if we call getAllResponseHeaders on a cancelled request. */
    return false;
  }

  return this.successBase();
}

/* Work around a Prototype bug; it discards exceptions instead of letting them fall back
 * to the browser where they'll be logged. */
Ajax.Responders.register({
  onException: function(request, exception) { (function() { throw exception; }).defer(); }
});

/*
 * Return the values of list starting at idx and moving outwards.
 *
 * sort_array_by_distance([0,1,2,3,4,5,6,7,8,9], 5)
 * [5,4,6,3,7,2,8,1,9,0]
 */
sort_array_by_distance = function(list, idx)
{
  var ret = [];
  ret.push(list[idx]);
  for(var distance = 1; ; ++distance)
  {
    var length = ret.length;
    if(idx-distance >= 0)
      ret.push(list[idx-distance]);
    if(idx+distance < list.length)
      ret.push(list[idx+distance]);
    if(length == ret.length)
      break;
  }

  return ret;
}

/* When element is dragged, the document moves around it.  If scroll_element is true, the
 * element should be positioned (eg. position: absolute), and the element itself will be
 * scrolled. */
WindowDragElement = function(element, scroll_element)
{
  this.mousemove_event = this.mousemove_event.bindAsEventListener(this);
  this.mousedown_event = this.mousedown_event.bindAsEventListener(this);
  this.mouseup_event = this.mouseup_event.bindAsEventListener(this);
  this.click_event = this.click_event.bindAsEventListener(this);
  this.selectstart_event = this.selectstart_event.bindAsEventListener(this);

  this.element = element;
  this.scroll_element = scroll_element;
  this.last_mouse_x = null;
  this.last_mouse_y = null;
  this.dragging = false;

  /*
   * Starting drag on mousedown works in most browsers, but has an annoying side-
   * effect: we need to stop the event to prevent any browser drag operations from
   * happening, and that'll also prevent clicking the element from focusing the
   * window.
   *
   * Using dragstart doesn't have that problem, but doesn't work in Opera.
   *
   * Finally, we may or may not get a click event after mouseup.  This is a pain:
   * if we get a click event, we need to cancel it if we dragged, but we may not
   * get a click event at all; detecting whether a click event came from the drag
   * or not is difficult.  Cancelling mouseup has no effect.  FF, IE7 and Opera still
   * send the click event if their dragstart or mousedown event is cancelled; WebKit
   * doesn't.
   */
  if(window.opera)
    element.observe("mousedown", this.mousedown_event);
  else
    element.observe("dragstart", this.mousedown_event);

  if(!Prototype.Browser.WebKit)
    element.observe("click", this.click_event);
}

WindowDragElement.prototype.mousemove_event = function(event)
{
  event.stop();
  
  var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);

  var x = event.pointerX() - scrollLeft;
  var y = event.pointerY() - scrollTop;

  this.last_mouse_x = x;
  this.last_mouse_y = y;
  if(!this.dragging)
    return;
  if(!this.dragged)
  {
    this.dragged = true;
    document.body.addClassName("dragging");
  }

  var diff_x = x - this.anchor_x;
  var diff_y = y - this.anchor_y;

  if(this.scroll_element)
  {
    var scrollLeft = this.scroll_anchor_x + diff_x;
    var scrollTop = this.scroll_anchor_y + diff_y;

    /* Don't allow dragging the image off the screen; there'll be no way to
     * get it back. */
    var window_size = document.viewport.getDimensions();
    var min_visible = Math.min(100, this.element.offsetWidth);
    scrollLeft = Math.max(scrollLeft, min_visible - this.element.offsetWidth);
    scrollLeft = Math.min(scrollLeft, window_size.width - min_visible);

    var min_visible = Math.min(100, this.element.offsetHeight);
    scrollTop = Math.max(scrollTop, min_visible - this.element.offsetHeight);
    scrollTop = Math.min(scrollTop, window_size.height - min_visible);
    this.element.setStyle({left: scrollLeft + "px", top: scrollTop + "px"});
  }
  else
  {
    var scrollLeft = this.scroll_anchor_x - diff_x;
    var scrollTop = this.scroll_anchor_y - diff_y;
    scrollTo(scrollLeft, scrollTop);
  }
}

WindowDragElement.prototype.mousedown_event = function(event)
{
  /* Only check if this is a left click if we're using the mousedown event; IE7
   * doesn't set the button property on dragstart. */
  if(event.type == "mousedown" && !event.isLeftClick())
    return;

  Event.observe(document, "mouseup", this.mouseup_event);
  Event.observe(document, "mousemove", this.mousemove_event);
  Event.observe(document, "selectstart", this.selectstart_event);

  this.dragging = true;
  this.dragged = false;

  var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);

  if(this.scroll_element)
  {
    this.scroll_anchor_x = this.element.offsetLeft;
    this.scroll_anchor_y = this.element.offsetTop;
  }
  else
  {
    this.scroll_anchor_x = scrollLeft;
    this.scroll_anchor_y = scrollTop;
  }

  this.anchor_x = event.pointerX() - scrollLeft;
  this.anchor_y = event.pointerY() - scrollTop;
  event.preventDefault();
}

WindowDragElement.prototype.mouseup_event = function(event)
{
  if(!event.isLeftClick())
    return;

  if(this.dragging)
  {
    this.dragging = false;
    document.body.removeClassName("dragging");
  }

  Event.stopObserving(document, "mouseup", this.mouseup_event);
  Event.stopObserving(document, "mousemove", this.mousemove_event);
  Event.stopObserving(document, "selectstart", this.selectstart_event);
}

WindowDragElement.prototype.click_event = function(event)
{
  /* If this click was part of a drag, cancel the click. */
  if(this.dragged)
    event.stop();
  this.dragged = false;
}

WindowDragElement.prototype.selectstart_event = function(event)
{
  event.stop();
}

