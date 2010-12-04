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
 * - window.scrollTo(0, 1) to scroll the address bar off screen, which increases the window
 *   size to the maximum
 * - wait a little while; unbelievably, window.scrollTo on Android animates rather than
 *   snapping to the position as all sane browsers do
 * - set the body to the size of the window
 * - hide the padding div
 * - synthesize a new resize event to continue other event handlers that we originally cancelled
 *
 * resize will always be fired at least once as a result of constructing this class.
 *
 * This is only used on Android.
 */

function AndroidDetectWindowSize()
{
  /* This is shown to make sure we can scroll the address bar off.  It goes outside
   * of #sizing-body, so it's not clipped.  By not changing #sizing-body itself, we
   * avoid reflowing the entire document more than once, when we finish. */
  this.padding = document.createElement("DIV");
  this.padding.setStyle({width: "5000px", height: "5000px"});
  this.padding.hide();
  document.documentElement.appendChild(this.padding);

  this.window_size = [0, 0];
  this.finish = this.finish.bind(this);
  this.event_onresize = this.event_onresize.bindAsEventListener(this);

  this.finish_timer = null;
  this.last_window_orientation = window.orientation;

  window.addEventListener("resize", this.event_onresize, true);

  this.active = false;

  /* Kick off a detection cycle.  On Android 2.1, we can't do this immediately after onload; for
   * some reason this triggers some very strange browser bug where the screen will jitter up and
   * down, as if our scrollTo is competing against the browser trying to scroll somewhere.  For
   * older browsers, delay before starting.  This is no longer needed on Android 2.2. */
  var delay_seconds = 0;
  var m = navigator.userAgent.match(/Android (\d+\.\d+)/);
  if(m && parseFloat(m[1]) < 2.2)
  {
    debug("Delaying bootstrapping due to Android version " + m[1]);
    delay_seconds = 1;
  }

  /* When this detection cycle completes, a resize event will be fired so listeners can
   * act on the detected window size. */
  this.begin.bind(this).delay(delay_seconds);
}

/* Return true if Android resize handling is needed. */
AndroidDetectWindowSize.required = function()
{
  // XXX: be more specific
  return navigator.userAgent.indexOf("Android") != -1;
}

/* After we set the window size, dispatch a resize event so other listeners will notice
 * it. */
AndroidDetectWindowSize.prototype.dispatch_resize_event = function()
{
  debug("dispatch final resize event");
  var e = document.createEvent("Event");
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
    debug("skipped window size detection");
    return;
  }

  debug("begin window size detection, " + initial_window_size[0] + "x" + initial_window_size[1] + " at start");
  this.active = true;
  this.padding.show();

  window.scrollTo(0, 1);
  this.finish_timer = window.setTimeout(this.finish, 500);
}

AndroidDetectWindowSize.prototype.end = function()
{
  if(!this.active)
    return;
  this.active = false;

  if(this.begin_timer != null)
    window.clearTimeout(this.begin_timer);
  this.begin_timer = null;

  if(this.finish_timer != null)
    window.clearTimeout(this.finish_timer);
  this.finish_timer = null;

  this.padding.hide();
}

AndroidDetectWindowSize.prototype.current_window_size = function()
{
  return [window.innerWidth, window.innerHeight];
}

AndroidDetectWindowSize.prototype.finish = function()
{
  if(!this.active)
    return;
  debug("window size detection: finish()");
  this.end();

  this.window_size = this.current_window_size();

  // We need to fudge the height up a pixel, or in many cases we'll end up with a white line
  // at the bottom of the screen.  This seems to be sub-pixel rounding error.
  debug("new window size: " + this.window_size[0] + "x" + this.window_size[1]);
  $("sizing-body").setStyle({width: this.window_size[0] + "px", height: (this.window_size[1]) + "px"});

  this.dispatch_resize_event();
}

AndroidDetectWindowSize.prototype.event_onresize = function(e)
{
  if(this.last_window_orientation != window.orientation)
  {
    e.stop();

    this.last_window_orientation = window.orientation;
    if(this.active)
    {
      /* The orientation changed while we were in the middle of detecting the resolution.
       * Start over. */
      debug("Orientation changed while already detecting window size; restarting");
      this.end();
    }
    else
    {
      debug("Resize received with an orientation change; beginning");
    }

    this.begin();
    return;
  }

  if(this.active)
  {
    /* Suppress resize events while we're active, since many of them will fire.
     * Once we finish, we'll fire a single one. */
    debug("stopping resize event while we're active");
    e.stop();
    return;
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
 * This is needed on Android and iPhone's WebKit.
 *
 * Note that this triggers a minor bug on Android: after firing a dblclick event,
 * we no longer receive mousemove events until the touch is released, which means
 * PreventDragScrolling can't cancel dragging.
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
 * Mobile WebKit has serious problems with the click event: it delays them for the
 * entire double-click timeout, and if a double-click happens it doesn't deliver the
 * click at all.  This makes clicks unresponsive, and it has this behavior even
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


/*
 * Save the URL hash to local DOM storage when it changes.  When called, restores the
 * previously saved hash.
 *
 * This is used on the iPhone only, and only when operating in web app mode (window.standalone).
 * The iPhone doesn't update the URL hash saved in the web app shortcut, nor does it
 * remember the current URL when using make-believe multitasking, which means every time
 * you switch out and back in you end up back to wherever you were when you first created
 * the web app shortcut.  Saving the URL hash allows switching out and back in without losing
 * your place.
 *
 * This should only be used in environments where it's been tested and makes sense.  If used
 * in a browser, or in a web app environment that properly tracks the URL hash, this will
 * just interfere with normal operation.
 */
var MaintainUrlHash = function()
{
  /* This requires DOM storage. */
  if(!("localStorage" in window))
    return;

  /* When any part of the URL hash changes, save it. */
  var update_stored_hash = function(changed_hash_keys, old_hash, new_hash)
  {
    var hash = localStorage.current_hash = UrlHash.get_raw_hash();
  }
  UrlHash.observe(null, update_stored_hash);

  /* Restore the previous hash, if any. */
  var hash = localStorage.getItem("current_hash");
  if(hash)
    UrlHash.set_raw_hash(hash);
}

/*
 * In some versions of the browser, iPhones don't send resize events after an
 * orientation change, so we need to fire it ourself.  Try not to do this if not
 * needed, so we don't fire spurious events.
 *
 * This is never needed in web app mode.
 *
 * Needed on user-agents:
 * iPhone OS 4_0_2 ... AppleWebKit/532.9 ... Version/4.0.5
 * iPhone OS 4_1 ... AppleWebKit/532.9 ... Version/4.0.5
 *
 * Not needed on:
 * (iPad, OS 3.2)
 * CPU OS 3_2 ... AppleWebKit/531.1.10 ... Version/4.0.4 
 * iPhone OS 4_2 ... AppleWebKit/533.17.9 ... Version/5.0.2
 *
 * This seems to be specific to Version/4.0.5.
 */
var SendMissingResizeEvents = function()
{
  if(window.navigator.standalone)
    return;
  if(navigator.userAgent.indexOf("Version/4.0.5") == -1)
    return;

  var last_seen_orientation = window.orientation;
  window.addEventListener("orientationchange", function(e) {
    if(last_seen_orientation == window.orientation)
      return;
    last_seen_orientation = window.orientation;

    debug("dispatch fake resize event");
    var e = document.createEvent("Event");
    e.initEvent("resize", true, true);
    document.documentElement.dispatchEvent(e);
  }, true);
}

var InitializeFullScreenBrowserHandlers = function()
{
  /* These handlers deal with heavily browser-specific issues.  Only install them
   * on browsers that have been tested to need them. */
  if(navigator.userAgent.indexOf("Android") != -1 && navigator.userAgent.indexOf("WebKit") != -1)
  {
    new ResponsiveSingleClick();
    new EmulateDoubleClick();
  }
  else if((navigator.userAgent.indexOf("iPhone") != -1 || navigator.userAgent.indexOf("iPad") != -1)
      && navigator.userAgent.indexOf("WebKit") != -1)
  {
    new ResponsiveSingleClick();
    new EmulateDoubleClick();

    /* In web app mode only: */
    if(window.navigator.standalone)
      MaintainUrlHash();

    SendMissingResizeEvents();
  }

  PreventDragScrolling();
}

SwipeHandler = function(element)
{
  this.element = element;
  this.dragger = new DragElement(element, { ondrag: this.ondrag.bind(this), onstartdrag: this.startdrag.bind(this) });
}

SwipeHandler.prototype.startdrag = function()
{
  this.swiped_horizontal = false;
  this.swiped_vertical = false;
}

SwipeHandler.prototype.ondrag = function(e)
{
  if(!this.swiped_horizontal)
  {
    // XXX: need a guessed DPI
    if(Math.abs(e.aX) > 100)
    {
      this.element.fire("swipe:horizontal", {right: e.aX > 0});
      this.swiped_horizontal = true;
    }
  }

  if(!this.swiped_vertical)
  {
    if(Math.abs(e.aY) > 100)
    {
      this.element.fire("swipe:vertical", {down: e.aY > 0});
      this.swiped_vertical = true;
    }
  }
}

SwipeHandler.prototype.destroy = function()
{
  this.dragger.destroy();
}

