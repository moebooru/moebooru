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
 * - window.scrollTo(0, 99999999) to scroll the address bar off screen, which increases the window
 *   size to the maximum.  We use a big value here, because Android has a broken scrollTo, which
 *   animates to the specified position.  If we say (0, 1), then it'll take a while to scroll
 *   there; by giving it a huge value, it'll scroll past the scrollbar in one frame.
 * - wait a little while.  We need to wait for one frame of scrollTo's animation, but we don't
 *   know how long that'll be, so we need to poll with a timer periodically, checking
 *   document.body.scrollTop.
 * - set the body to the size of the window
 * - hide the padding div
 * - synthesize a new resize event to continue other event handlers that we originally cancelled
 *
 * resize will always be fired at least once as a result of constructing this class.
 *
 * This is only used on Android.
 */

window.AndroidDetectWindowSize = function()
{
  $("sizing-body").setStyle({overflow: "hidden"});

  /* This is shown to make sure we can scroll the address bar off.  It goes outside
   * of #sizing-body, so it's not clipped.  By not changing #sizing-body itself, we
   * avoid reflowing the entire document more than once, when we finish. */
  this.padding = document.createElement("DIV");
  this.padding.setStyle({width: "1px", height: "5000px"});
  this.padding.style.visibility = "hidden";
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
  return navigator.userAgent.indexOf("Android") !== -1;
};

/* After we set the window size, dispatch a resize event so other listeners will notice
 * it. */
AndroidDetectWindowSize.prototype.dispatch_resize_event = function()
{
  debug("dispatch final resize event");
  var e = document.createEvent("Event");
  e.initEvent("resize", true, true);
  document.documentElement.dispatchEvent(e);
};

AndroidDetectWindowSize.prototype.begin = function()
{
  if(this.active)
    return;

  var initial_window_size = this.current_window_size();
  if(this.window_size && initial_window_size[0] === this.window_size[0] && initial_window_size[1] === this.window_size[1])
  {
    debug("skipped window size detection");
    return;
  }

  debug("begin window size detection, " + initial_window_size[0] + "x" + initial_window_size[1] + " at start (scroll pos " + document.documentElement.scrollHeight + ")");
  this.active = true;
  this.padding.show();

  /* If we set a sizing-body the last time, remove it before running again. */
  $("sizing-body").setStyle({width: "0px", height: "0px"});

  window.scrollTo(0, 99999999);
  this.finish_timer = window.setTimeout(this.finish, 0);
};

AndroidDetectWindowSize.prototype.end = function()
{
  if(!this.active)
    return;
  this.active = false;

  if(this.begin_timer !== null)
    window.clearTimeout(this.begin_timer);
  this.begin_timer = null;

  if(this.finish_timer !== null)
    window.clearTimeout(this.finish_timer);
  this.finish_timer = null;

  this.padding.hide();
};

AndroidDetectWindowSize.prototype.current_window_size = function()
{
  var size = [window.innerWidth, window.innerHeight];

  // We need to fudge the height up a pixel, or in many cases we'll end up with a white line
  // at the bottom of the screen (or the top in 2.3).  This seems to be sub-pixel rounding
  // error.
  ++size[1];

  return size;
};

AndroidDetectWindowSize.prototype.finish = function()
{
  if(!this.active)
    return;
  debug("window size detection: finish(), at " + window.scrollY);

  /* scrollTo is supposed to be synchronous.  Android's animates.  Worse, the time it'll
   * update the animation is nondeterministic; it might happen as soon as we return from
   * calling scrollTo, or it might take a while.  Check whether we've scrolled down; if
   * we're still at the top, keep waiting. */
  if(window.scrollY === 0)
  {
    console.log("Waiting for scroll...");
    this.finish_timer = window.setTimeout(this.finish, 10);
    return;
  }

  /* The scroll may still be trying to run. */
  window.scrollTo(window.scrollX, window.scrollY);
  this.end();

  this.window_size = this.current_window_size();

  debug("new window size: " + this.window_size[0] + "x" + this.window_size[1]);
  $("sizing-body").setStyle({width: this.window_size[0] + "px", height: (this.window_size[1]) + "px"});

  this.dispatch_resize_event();
};

AndroidDetectWindowSize.prototype.event_onresize = function(e)
{
  if(this.last_window_orientation !== window.orientation)
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
};


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

window.EmulateDoubleClick = function()
{
  this.touchstart_event = this.touchstart_event.bindAsEventListener(this);
  this.touchend_event = this.touchend_event.bindAsEventListener(this);
  this.last_click = null;

  window.addEventListener("touchstart", this.touchstart_event, false);
  window.addEventListener("touchend", this.touchend_event, false);
}

EmulateDoubleClick.prototype.touchstart_event = function(event)
{
  var this_touch = event.changedTouches[0];
  var last_click = this.last_click;

  /* Don't store event.changedTouches or any of its contents.  Some browsers modify these
   * objects in-place between events instead of properly returning unique events. */
  var this_click = {
    timeStamp: event.timeStamp,
    target: event.target,
    identifier: this_touch.identifier,
    position: [this_touch.screenX, this_touch.screenY],
    clientPosition: [this_touch.clientX, this_touch.clientY]
  };
  this.last_click = this_click;

  if(last_click === null || last_click === undefined)
      return;

  /* If the first tap was never released then this is a multitouch double-tap.
   * Clear the original tap and don't fire anything. */
  if(event.touches.length > 1)
    return;

  /* Check that not too much time has passed. */
  var time_since_previous = event.timeStamp - last_click.timeStamp;
  if(time_since_previous > 500)
    return;

  /* Check that the clicks aren't too far apart. */
  var distance = Math.pow(this_touch.screenX - last_click.position[0], 2) + Math.pow(this_touch.screenY - last_click.position[1], 2);
  if(distance > 500)
    return;

  if(event.target !== last_click.target)
    return;

  /* Synthesize a dblclick event.  Use the coordinates of the first click as the location
   * and not the second click, since if the position matters the user's first click of
   * a double-click is probably more precise than the second. */
  var e = document.createEvent("MouseEvent");
  e.initMouseEvent("dblclick", true, true, window,
                     2,
                     last_click.position[0], last_click.position[1],
                     last_click.clientPosition[0], last_click.clientPosition[1],
                     false, false,
                     false, false,
                     0, null);

  this.last_click = null;
  event.target.dispatchEvent(e);
};

EmulateDoubleClick.prototype.touchend_event = function(event)
{
  if(this.last_click === null || this.last_click === undefined)
    return;

  var last_click_identifier = this.last_click.identifier;
  if(last_click_identifier === null || last_click_identifier === undefined)
    return;

  var last_click_position = this.last_click.position;
  var this_click = event.changedTouches[0];
  if(this_click.identifier === last_click_identifier)
  {
    /* If the touch moved too far when it was removed, don't fire a doubleclick; for
     * example, two quick swipe gestures aren't a double-click. */
    var distance = Math.pow(this_click.screenX - last_click_position[0], 2) + Math.pow(this_click.screenY - last_click_position[1], 2);
    if(distance > 500)
    {
      this.last_click = null;
      return;
    }
  }
};

/*
 * Mobile WebKit has serious problems with the click event: it delays them for the
 * entire double-click timeout, and if a double-click happens it doesn't deliver the
 * click at all.  This makes clicks unresponsive, and it has this behavior even
 * when the page can't be zoomed, which means nothing happens at all.
 *
 * Generate click events from touchend events to bypass this mess.
 */
window.ResponsiveSingleClick = function()
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
};

ResponsiveSingleClick.prototype.touchstart_event = function(event)
{
  /* If we get a touch while we already have a touch, it's multitouch, which is never
   * a click, so cancel the click. */
  if(this.last_touch !== null && this.last_touch !== undefined)
  {
    debug("Cancelling click (multitouch)");
    this.last_touch = null;
    return;
  }

  /* Watch out: in older versions of WebKit, the event.touches array and the items inside
   * it are actually modified in-place when the user drags.  That means that we can't just
   * save the entire array for comparing in touchend. */
  var touch = event.changedTouches[0];
  this.last_touch = [touch.screenX, touch.screenY];
};

ResponsiveSingleClick.prototype.touchend_event = function(event)
{
  var last_touch = this.last_touch;
  if(last_touch === null || last_touch === undefined)
    return;
  this.last_touch = null;

  var touch = event.changedTouches[0];
  var this_touch = [touch.screenX, touch.screenY];

  /* Don't trigger a click if the point has moved too far. */
  var distance = distance_squared(this_touch[0], this_touch[1], last_touch[0], last_touch[1]);
  if(distance > 50)
    return;

  var e = document.createEvent("MouseEvent");
  e.initMouseEvent("click", true, true, window,
                     1,
                     touch.screenX, touch.screenY,
                     touch.clientX, touch.clientY,
                     false, false,
                     false, false,
                     0, /* touch clicks are always button 0 - maybe not for multitouch */
                     null);
  e.synthesized_click = true;

  /* If we dispatch the click immediately, EmulateDoubleClick won't receive a
   * touchstart for the next click.  Defer dispatching it until we return. */
  (function() { event.target.dispatchEvent(e); }).defer();
};

/* Capture and cancel all clicks except the ones we generate. */
ResponsiveSingleClick.prototype.click_event = function(event)
{
  if(!event.synthesized_click)
    event.stop();
};

/* Stop all touchmove events on the document, to prevent dragging the window around. */
window.PreventDragScrolling = function()
{
  Element.observe(document, "touchmove", function(event) {
    event.preventDefault();
  });
};


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
  if(LocalStorageDisabled())
    return;

  /* When any part of the URL hash changes, save it. */
  var update_stored_hash = function(changed_hash_keys, old_hash, new_hash)
  {
    var hash = localStorage.current_hash = UrlHash.get_raw_hash();
  };
  UrlHash.observe(null, update_stored_hash);

  /* Restore the previous hash, if any. */
  var hash = localStorage.getItem("current_hash");
  if(hash)
    UrlHash.set_raw_hash(hash);
};

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
window.SendMissingResizeEvents = function()
{
  if(window.navigator.standalone)
    return;
  if(navigator.userAgent.indexOf("Version/4.0.5") === -1)
    return;

  var last_seen_orientation = window.orientation;
  window.addEventListener("orientationchange", function(e) {
    if(last_seen_orientation === window.orientation)
      return;
    last_seen_orientation = window.orientation;

    debug("dispatch fake resize event");
    e = document.createEvent("Event");
    e.initEvent("resize", true, true);
    document.documentElement.dispatchEvent(e);
  }, true);
};

window.InitializeFullScreenBrowserHandlers = function()
{
  /* These handlers deal with heavily browser-specific issues.  Only install them
   * on browsers that have been tested to need them. */
  if(navigator.userAgent.indexOf("Android") !== -1 && navigator.userAgent.indexOf("WebKit") !== -1)
  {
    new ResponsiveSingleClick();
    new EmulateDoubleClick();
  }
  else if((navigator.userAgent.indexOf("iPhone") !== -1 || navigator.userAgent.indexOf("iPad") !== -1 || navigator.userAgent.indexOf("iPod") !== -1) && navigator.userAgent.indexOf("WebKit") !== -1)
  {
    new ResponsiveSingleClick();
    new EmulateDoubleClick();

    /* In web app mode only: */
    if(window.navigator.standalone)
      MaintainUrlHash();

    SendMissingResizeEvents();
  }

  PreventDragScrolling();
};

window.SwipeHandler = function(element)
{
  this.element = element;
  this.dragger = new DragElement(element, { ondrag: this.ondrag.bind(this), onstartdrag: this.startdrag.bind(this) });
};

SwipeHandler.prototype.startdrag = function()
{
  this.swiped_horizontal = false;
  this.swiped_vertical = false;
};

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
};

SwipeHandler.prototype.destroy = function()
{
  this.dragger.destroy();
};

