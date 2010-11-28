/*
 * This file implements several helpers for fixing up full-page web apps on touchscreen
 * browsers:
 *
 * AndroidDetectWindowSize
 * EmulateDoubleClick
 * ResponsiveSingleClick
 * PreventDragScrolling
 *
 * Most of these are annoying hacks to work around the fact that WebKit on browsers was
 * designed with displaying scrolling webpages in mind, apparently without consideration
 * for full-screen applications: pages that should fill the screen at all times.  Most
 * of the browser mobile hacks no longer make sense: separate display viewports, touch
 * dragging, double-click zooming and their associated side-effects.
 */


/*
 * AndroidDetectWindowSize
 *
 * Implementing a full-page web app for Android is hard, because if you set the page to
 * "width: 100%; height: 100%;" it'll eat a big chunk of the screen with the address bar
 * which can't be scrolled off in that configuration.  We have to play games to figure out
 * the real size of the window, and set the body size to it explicitly.  This handler does
 * the following:
 *
 * - capture resize events
 * - cancel the resize event; we'll fire it again when we're done
 * - enable a large padding div, to ensure that we can scroll the window downward
 * - switch the body to overflow: auto
 * - window.scrollTo(0, 1) to scroll the address bar off screen, which increases the window
 *   size to the maximum
 * - wait a little while; unbelievably, window.scrollTo on Android animates rather than
 *   snapping to the position as all sane browsers do
 * - set the body to the size of the window
 * - hide the padding div and set the body back to overflow: hidden
 * - synthesize a new resize event to continue other event handlers that we originally cancelled
 *
 * resize will always be fired at least once as a result of constructing this class.
 *
 * This is only used on Android.
 */

function AndroidDetectWindowSize()
{
  /* This is shown to make sure we can scroll the address bar off. */
  this.padding = document.createElement("DIV");
  this.padding.setStyle({width: "5000px", height: "5000px"});
  this.padding.hide();
  document.documentElement.appendChild(this.padding);

  this.window_size = [0, 0];
  this.finish = this.finish.bind(this);
  this.event_onresize = this.event_onresize.bindAsEventListener(this);

  this.finish_timer = null;
  this.active = false;

  /* This will run a detection cycle, which will fire resize and then leave us capturing resize. */
  this.begin();
}

/* Return true if Android resize handling is needed. */
AndroidDetectWindowSize.required = function()
{
  // XXX: be more specific
  return navigator.userAgent.indexOf("Android") != -1;
}

/* Dispatch a resize event that we won't intercept, and which will continue on to regular
 * listeners.  This is used after we've completed processing. */
AndroidDetectWindowSize.prototype.dispatch_resize_event = function()
{
  debug.log("dispatch");
  var e = document.createEvent("Event");
  e.from_window_size_detection = true;
  e.initEvent("resize", true, true);
  document.documentElement.dispatchEvent(e);
}

AndroidDetectWindowSize.prototype.begin = function()
{
  if(this.active)
    return;

  var initial_window_size = this.current_window_size();
  if(this.window_size && initial_window_size[0] == this.window_size[0] && initial_window_size[1] == this.window_size[1])
  {
    debug.log("skipped");
    return;
  }

  debug.log("begin");
  document.body.setStyle({overflow: "auto"});
  this.window_size = initial_window_size;
  this.padding.show();
  this.active = true;
  window.removeEventListener("resize", this.event_onresize, true);

  if(this.finish_timer != null)
    this.finish_timer = window.clearTimeout(this.finish_timer);
  this.finish_timer = window.setTimeout(this.finish, 250);

  window.scrollTo(0, 1);
}

AndroidDetectWindowSize.prototype.end = function()
{
  if(!this.active)
    return;
  this.active = false;

  this.padding.hide();
  document.body.setStyle({overflow: "hidden"});
  window.addEventListener("resize", this.event_onresize, true);
}

AndroidDetectWindowSize.prototype.current_window_size = function()
{
  return [window.innerWidth, window.innerHeight];
}

AndroidDetectWindowSize.prototype.finish = function()
{
  if(!this.active)
    return;
  debug.log("finish()");
  this.end();

  this.window_size[0] = Math.max(this.window_size[0], window.innerWidth);
  this.window_size[1] = Math.max(this.window_size[1], window.innerHeight);

  /* If the orientation's been changed, start over. */
  var was_landscape = this.window_size[0] > this.window_size[1];
  var is_landscape = window.innerWidth > window.innerHeight;
  if(was_landscape != is_landscape)
  {
    debug.log("restart: orientation changed");
    this.end();
    this.begin();
    return;
  }

  // We need to fudge the height up a pixel, or in many cases we'll end up with a white line
  // at the bottom of the screen.  This seems to be sub-pixel rounding error.
  debug.log("new window size: " + this.window_size[0] + "x" + this.window_size[1]);
  document.body.setStyle({width: this.window_size[0] + "px", height: (this.window_size[1]+1) + "px"});

  this.dispatch_resize_event();
}

AndroidDetectWindowSize.prototype.event_onresize = function(e)
{
  /* Ignore events that we generated ourselves after completion. */
  if(e.from_window_size_detection)
  {
    debug.log("ignored");
    return;
  }

  debug.log("stopping resize event");
  e.stopPropagation();

  /* A resize event starts a new detection cycle, if we're not already in one. */
  if(!this.active)
  {
    debug.log("resize");
    this.begin();
  }
}


/*
 * Work around a bug on many touchscreen browsers: even when the page isn't
 * zoomable, dblclick is never fired.  We have to emulate it.
 *
 * This isn't an exact emulation of the event behavior:
 *
 * - It triggers from touchstart rather than mousedown.  The second mousedown
 *   of a double click isn't being fired reliably in Android's WebKit.
 *
 * - preventDefault on the triggering event should prevent a dblclick, but
 *   we can't find out if it's been called; there's nothing like Firefox's
 *   getPreventDefault.  We could mostly emulate this by overriding
 *   Event.preventDefault to set a flag that we can read.
 *
 * - The conditions for a double click won't match the ones of the platform.
 *
 * This is needed on Android's WebKit; untested on iPhone.
 */

function EmulateDoubleClick()
{
  this.touchstart_event = this.touchstart_event.bindAsEventListener(this);
  this.last_click_event = null;

  window.addEventListener("touchstart", this.touchstart_event, false);
}

EmulateDoubleClick.prototype.touchstart_event = function(event)
{
  var this_click = event;
  var last_click  = this.last_click_event;

  this.last_click_event = this_click;
  if(last_click == null)
      return;

  /* Check that not too much time has passed. */
  var time_since_previous = this_click.timeStamp - last_click.timeStamp;
  if(time_since_previous > 500)
    return;

  /* Check that the clicks aren't too far apart. */
  var distance = Math.pow(this_click.screenX - last_click.screenX, 2) + Math.pow(this_click.screenY - last_click.screenY, 2);
  if(distance > 8)
    return;

  /* Make sure these attributes match in both clicks: */
  var properties_to_match = ["ctrlKey", "altKey", "shiftKey", "metaKey", "target", "button"];
  for(var i = 0; i < properties_to_match.length; ++i)
  {
    var name = properties_to_match[i]
    if(this_click[name] != last_click[name])
      return;
  }

  /* Synthesize a dblclick event. */
  var e = document.createEvent("MouseEvent");
  e.initMouseEvent("dblclick", true, true, window, 
                     2,
                     this_click.screenX, this_click.screenY,
                     this_click.clientX, this_click.clientY, 
                     this_click.ctrlKey, this_click.altKey,
                     this_click.shiftKey, this_click.metaKey, 
                     this_click.button, null);

  this.last_click_event = null;
  this_click.target.dispatchEvent(e);
}

/* 
 * Android's WebKit has serious problems with the click event: it delays them for
 * the entire double-click timeout, and if a double-click happens it doesn't deliver
 * the click at all.  This makes clicks unresponsive, and it has this behavior even
 * when the page can't be zoomed, which means nothing happens at all.
 *
 * Generate click events from touchend events to bypass this mess.
 *
 * XXX: This needs to understand multitouch.
 */
ResponsiveSingleClick = function()
{
  this.click_event = this.click_event.bindAsEventListener(this);
  this.touchstart_event = this.touchstart_event.bindAsEventListener(this);
  this.touchend_event = this.touchend_event.bindAsEventListener(this);

  this.last_touch = null;

  window.addEventListener("touchstart", this.touchstart_event, false);
  window.addEventListener("touchend", this.touchend_event, false);

  /* This is a capturing listener, so we can intercept clicks before they're
   * delivered to anyone. */
  window.addEventListener("click", this.click_event, true);
}

ResponsiveSingleClick.prototype.touchstart_event = function(event)
{
  /* Watch out: in Android 2.1's browser, the event.touches array and the items inside
   * it are actually modified in-place when the user drags.  That means that we can't just
   * save the entire array for comparing in touchend. */
  var touch = event.touches.item(0);
  this.last_touch = [touch.screenX, touch.screenY];
}

ResponsiveSingleClick.prototype.touchend_event = function(event)
{
  var touch = event.changedTouches.item(0);
  var this_touch = [touch.screenX, touch.screenY];
  var last_touch = this.last_touch;

  /* Don't trigger a click if the point has moved too far. */
  var distance = distance_squared(this_touch[0], this_touch[1], last_touch[0], last_touch[1]);
  if(distance > 50)
    return;

  var e = document.createEvent("MouseEvent");
  e.initMouseEvent("click", true, true, window, 
                     1,
                     event.screenX, event.screenY,
                     event.clientX, event.clientY, 
                     event.ctrlKey, event.altKey,
                     event.shiftKey, event.metaKey, 
                     0, /* touch clicks are always button 0 - maybe not for multitouch */
                     null);
  e.synthesized_click = true;

  /* If we dispatch the click immediately, EmulateDoubleClick won't receive a
   * touchstart for the next click.  Defer dispatching it until we return. */
  (function() { event.target.dispatchEvent(e); }).defer();
}

/* Capture and cancel all clicks except the ones we generate. */
ResponsiveSingleClick.prototype.click_event = function(event)
{
  if(!event.synthesized_click)
    event.stop();
}

/* Stop all touchmove events on the document, to prevent dragging the window around. */
PreventDragScrolling = function()
{
  Element.observe(document, "touchmove", function(event) {
    event.preventDefault();
  });
}

var InitializeFullScreenBrowserHandlers = function()
{
  /* These handlers deal with heavily browser-specific issues.  Only install them
   * on browsers that have been tested to need them. */
  if(navigator.userAgent.indexOf("Android") != -1 && navigator.userAgent.indexOf("WebKit") != -1)
  {
    new ResponsiveSingleClick();
    new EmulateDoubleClick();
    PreventDragScrolling();
  }
}

