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

function time_ago_in_words(from_time, to_time)
{
  if(to_time == null)
    to_time = new Date();

  var from_time = from_time.valueOf();
  var to_time = to_time.valueOf();
  distance_in_seconds = Math.abs((to_time - from_time)/1000).round();
  distance_in_minutes = (distance_in_seconds/60).round();

  if(distance_in_minutes <= 1)
    return "1 minute";

  if(distance_in_minutes <= 44)
    return distance_in_minutes + " minutes";

  if(distance_in_minutes <= 89)
    return "1 hour";

  if(distance_in_minutes <= 1439)
  {
    var hours = distance_in_minutes / 60;
    hours = (hours - 0.5).round(); // round down
    return hours + " hours";
  }

  if(distance_in_minutes <= 2879)
    return "1 day";

  if(distance_in_minutes <= 43199)
  {
    var days = distance_in_minutes / 1440;
    days = (days - 0.5).round(); // round down
    return days + " days";
  }

  if(distance_in_minutes <= 86399)
    return "1 month";

  if(distance_in_minutes <= 525959)
  {
    var months = distance_in_minutes / 43200;
    months = (months - 0.5).round(); // round down
    return months + " months";
  }

  var years = (distance_in_minutes / 525960).toFixed(1);
  return years + " years";
}

scale = function(x, l1, h1, l2, h2)
{
  return ((x - l1) * (h2 - l2) / (h1 - l1) + l2);
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
    if(element.innerText != null)
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
 * Exceptions thrown from event handlers tend to get lost.  Sometimes they trigger
 * window.onerror, but not reliably.  Catch exceptions out of event handlers and
 * throw them from a deferred context, so they'll make it up to the browser to be
 * logged.
 *
 * This depends on bindAsEventListener actually only being used for event listeners,
 * since it eats exceptions.
 */
Function.prototype.bindAsEventListener = function()
{
  var __method = this, args = $A(arguments), object = args.shift();
  return function(event) {
    try {
      return __method.apply(object, [event || window.event].concat(args));
    } catch(exception) {
      (function() { throw exception; }).defer();
    }
  }
}

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

/* Return the squared distance between two points. */
distance_squared = function(x1, y1, x2, y2)
{
  return Math.pow(x1 - x2, 2) + Math.pow(y1 - y2, 2);
}

/* Return the size of the window. */
getWindowSize = function()
{
  var size = {};
  if(window.innerWidth != null)
  {
    size.width = window.innerWidth;
    size.height = window.innerHeight;
  }
  else
  {
    /* IE: */
    size.width = document.documentElement.clientWidth;
    size.height = document.documentElement.clientHeight;
  }
  return size;
}

Prototype.Browser.AndroidWebKit = (navigator.userAgent.indexOf("Android") != -1 && navigator.userAgent.indexOf("WebKit") != -1);

/* Some UI simply doesn't make sense on a touchscreen, and may need to be disabled or changed.
 * It'd be nice if this could be done generically, but this is the best available so far ... */
Prototype.BrowserFeatures.Touchscreen = (function() {
  /* iOS WebKit has window.Touch, a constructor for Touch events. */
  if(window.Touch)
    return true;

  // Mozilla/5.0 (Linux; U; Android 2.2; en-us; sdk Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1
  if(navigator.userAgent.indexOf("Mobile Safari/") != -1)
    return true;

  // Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_2 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Mobile/8C134
  if(navigator.userAgent.indexOf("Mobile/") != -1)
    return true;

  return false;
})();


/* When element is dragged, the document moves around it.  If scroll_element is true, the
 * element should be positioned (eg. position: absolute), and the element itself will be
 * scrolled. */
DragElement = function(element, options)
{
  this.options = options || {};
  if(this.options.snap_pixels == null)
    this.options.snap_pixels = 10;

  this.mousemove_event = this.mousemove_event.bindAsEventListener(this);
  this.mousedown_event = this.mousedown_event.bindAsEventListener(this);
  this.dragstart_event = this.dragstart_event.bindAsEventListener(this);
  this.mouseup_event = this.mouseup_event.bindAsEventListener(this);
  this.click_event = this.click_event.bindAsEventListener(this);
  this.selectstart_event = this.selectstart_event.bindAsEventListener(this);

  this.touchmove_event = this.touchmove_event.bindAsEventListener(this);
  this.touchstart_event = this.touchstart_event.bindAsEventListener(this);
  this.touchend_event = this.touchend_event.bindAsEventListener(this);

  this.move_timer_update = this.move_timer_update.bind(this);

  this.element = element;
  this.dragging = false;

  this.drag_handlers = [];
  this.handlers = [];

  /*
   * Starting drag on mousedown works in most browsers, but has an annoying side-
   * effect: we need to stop the event to prevent any browser drag operations from
   * happening, and that'll also prevent clicking the element from focusing the
   * window.  Stop the actual drag in dragstart.  We won't get mousedown in
   * Opera, but we don't need to stop it there either.
   *
   * Sometimes drag events can leak through, and attributes like -moz-user-select may
   * be needed to prevent it.
   */
  this.handlers.push(element.on("mousedown", this.mousedown_event));
  this.handlers.push(element.on("dragstart", this.dragstart_event));

  this.handlers.push(element.on("touchstart", this.touchstart_event));
  this.handlers.push(element.on("touchmove", this.touchmove_event));

  /*
   * We may or may not get a click event after mouseup.  This is a pain: if we get a
   * click event, we need to cancel it if we dragged, but we may not get a click event
   * at all; detecting whether a click event came from the drag or not is difficult.
   * Cancelling mouseup has no effect.  FF, IE7 and Opera still send the click event
   * if their dragstart or mousedown event is cancelled; WebKit doesn't.
   */
  if(!Prototype.Browser.WebKit)
    this.handlers.push(element.on("click", this.click_event));
}

DragElement.prototype.destroy = function()
{
  this.stop_dragging();
  this.handlers.each(function(h) { h.stop(); });
  this.handlers = [];
}

DragElement.prototype.move_timer_update = function()
{
  this.move_timer = null;

  if(!this.options.ondrag)
    return;

  if(this.last_event_params == null)
    return;

  var last_event_params = this.last_event_params;
  this.last_event_params = null;

  var x = last_event_params.x;
  var y = last_event_params.y;

  var anchored_x = x - this.anchor_x;
  var anchored_y = y - this.anchor_y;

  var relative_x = x - this.last_x;
  var relative_y = y - this.last_y;
  this.last_x = x;
  this.last_y = y;

  if(this.options.ondrag)
    this.options.ondrag({
      dragger: this,
      x: x,
      y: y,
      aX: anchored_x,
      aY: anchored_y,
      dX: relative_x,
      dY: relative_y,
      latest_event: last_event_params.event
    });
}

DragElement.prototype.mousemove_event = function(event)
{
  event.stop();
  
  var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);

  var x = event.pointerX() - scrollLeft;
  var y = event.pointerY() - scrollTop;
  this.handle_move_event(event, x, y);
}

DragElement.prototype.touchmove_event = function(event)
{
  /* Ignore touches other than the one we started with. */
  var touch = null;
  for(var i = 0; i < event.touches.length; ++i)
  {
    touch = event.touches.item(i);
    if(touch.identifier == this.dragging_touch_identifier)
      break;
  }
  if(touch == null)
    return;

  event.preventDefault();

  var x = touch.pageX;
  var y = touch.pageY;

  this.handle_move_event(event, x, y);
}

DragElement.prototype.handle_move_event = function(event, x, y)
{
  if(!this.dragging)
    return;

  if(!this.dragged)
  {
    var distance = Math.pow(x - this.anchor_x, 2) + Math.pow(y - this.anchor_y, 2);
    var snap_pixels = this.options.snap_pixels;
    snap_pixels *= snap_pixels;

    if(distance < snap_pixels) // 10 pixels
      return;
  }

  if(!this.dragged)
  {
    if(this.options.onstartdrag)
    {
      /* Call the onstartdrag callback.  If it returns true, cancel the drag. */
      if(this.options.onstartdrag({ handler: this, latest_event: event }))
      {
        this.dragging = false;
        return;
      }
    }

    this.dragged = true;
    $(document.body).addClassName("dragging");
  }

  this.last_event_params = {
    x: x,
    y: y,
    event: event
  };

  if(this.dragging_by_touch && Prototype.Browser.AndroidWebKit)
  {
    /* Touch events on Android tend to queue up when they come in faster than we
     * can process.  Set a timer, so we discard multiple events in quick succession. */
    if(this.move_timer == null)
      this.move_timer = window.setTimeout(this.move_timer_update, 10);
  }
  else
  {
    this.move_timer_update();
  }
}

DragElement.prototype.mousedown_event = function(event)
{
  if(!event.isLeftClick())
    return;

  var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);
  var x = event.pointerX() - scrollLeft;
  var y = event.pointerY() - scrollTop;

  this.start_dragging(event, false, x, y, 0);
}

DragElement.prototype.touchstart_event = function(event)
{
  /* If we have multiple touches, find the first one that actually refers to us. */
  var touch = null;
  for(var i = 0; i < event.touches.length; ++i)
  {
    touch = event.touches.item(i);
    if(touch.target.isParentNode(this.element))
      break;
  }
  if(touch == null)
    return;

  var x = touch.pageX;
  var y = touch.pageY;
  
  this.start_dragging(event, true, x, y, touch.identifier);
}

DragElement.prototype.start_dragging = function(event, touch, x, y, touch_identifier)
{
  /* If we've been started with a touch event, only listen for touch events.  If we've
   * been started with a mouse event, only listen for mouse events.  We may receive
   * both sets of events, and the anchor coordinates for the two may not be compatible. */
  this.drag_handlers.push(document.on("selectstart", this.selectstart_event));
  if(touch)
  {
    this.drag_handlers.push(document.on("touchend", this.touchend_event));
    this.drag_handlers.push(document.on("touchmove", this.touchmove_event));
  }
  else
  {
    this.drag_handlers.push(document.on("mouseup", this.mouseup_event));
    this.drag_handlers.push(document.on("mousemove", this.mousemove_event));
  }

  this.dragging = true;
  this.dragged = false;
  this.dragging_by_touch = touch;
  this.dragging_touch_identifier = touch_identifier;

  this.anchor_x = x;
  this.anchor_y = y;
  this.last_x = this.anchor_x;
  this.last_y = this.anchor_y;
}

DragElement.prototype.touchend_event = function(event)
{
  this.stop_dragging();
}

DragElement.prototype.mouseup_event = function(event)
{
  if(!event.isLeftClick())
    return;

  this.stop_dragging();
}

DragElement.prototype.stop_dragging = function()
{
  if(this.dragging)
  {
    this.dragging = false;
    $(document.body).removeClassName("dragging");

    if(this.options.onenddrag)
      this.options.onenddrag(this);
  }

  this.drag_handlers.each(function(h) { h.stop(); });
  this.drag_handlers = [];
}

DragElement.prototype.click_event = function(event)
{
  /* If this click was part of a drag, cancel the click. */
  if(this.dragged)
    event.stop();
  this.dragged = false;
}

DragElement.prototype.dragstart_event = function(event)
{
  event.preventDefault();
}

DragElement.prototype.selectstart_event = function(event)
{
  event.stop();
}

/* When element is dragged, the document moves around it.  If scroll_element is true, the
 * element should be positioned (eg. position: absolute), and the element itself will be
 * scrolled. */
WindowDragElement = function(element)
{
  this.element = element;
  this.dragger = new DragElement(element, { ondrag: this.ondrag.bind(this), onstartdrag: this.startdrag.bind(this) });
}

WindowDragElement.prototype.startdrag = function()
{
  this.scroll_anchor_x = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
  this.scroll_anchor_y = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);
}

WindowDragElement.prototype.ondrag = function(e)
{
  var scrollLeft = this.scroll_anchor_x - e.aX;
  var scrollTop = this.scroll_anchor_y - e.aY;
  scrollTo(scrollLeft, scrollTop);
}

/* element should be positioned (eg. position: absolute).  When the element is dragged,
 * scroll it around. */
WindowDragElementAbsolute = function(element, ondrag_callback)
{
  this.element = element;
  this.ondrag_callback = ondrag_callback;
  this.disabled = false;
  this.dragger = new DragElement(element, {
    ondrag: this.ondrag.bind(this),
    onstartdrag: this.startdrag.bind(this)
  });
}

WindowDragElementAbsolute.prototype.set_disabled = function(b) { this.disabled = b; }

WindowDragElementAbsolute.prototype.startdrag = function()
{
  if(this.disabled)
    return true; /* cancel */

  this.scroll_anchor_x = this.element.offsetLeft;
  this.scroll_anchor_y = this.element.offsetTop;
  return false;
}

WindowDragElementAbsolute.prototype.ondrag = function(e)
{
  var scrollLeft = this.scroll_anchor_x + e.aX;
  var scrollTop = this.scroll_anchor_y + e.aY;

  /* Don't allow dragging the image off the screen; there'll be no way to
   * get it back. */
  var window_size = getWindowSize();
  var min_visible = Math.min(100, this.element.offsetWidth);
  scrollLeft = Math.max(scrollLeft, min_visible - this.element.offsetWidth);
  scrollLeft = Math.min(scrollLeft, window_size.width - min_visible);

  var min_visible = Math.min(100, this.element.offsetHeight);
  scrollTop = Math.max(scrollTop, min_visible - this.element.offsetHeight);
  scrollTop = Math.min(scrollTop, window_size.height - min_visible);
  this.element.setStyle({left: scrollLeft + "px", top: scrollTop + "px"});

  if(this.ondrag_callback)
    this.ondrag_callback();
}

WindowDragElementAbsolute.prototype.destroy = function()
{
  this.dragger.destroy();
}

