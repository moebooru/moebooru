"use strict";

var DragElement = function(element, options)
{
    this.options = options || {};
    if(this.options.snap_pixels == null)
        this.options.snap_pixels = 10;
    this.ignore_mouse_events_until = null;

    this.mousemove_event = this.mousemove_event.bind(this);
    this.mousedown_event = this.mousedown_event.bind(this);
    this.dragstart_event = this.dragstart_event.bind(this);
    this.mouseup_event = this.mouseup_event.bind(this);
    this.click_event = this.click_event.bind(this);
    this.touchmove_event = this.touchmove_event.bind(this);
    this.touchstart_event = this.touchstart_event.bind(this);
    this.touchend_event = this.touchend_event.bind(this);
    this.move_timer_update = this.move_timer_update.bind(this);

    this.element = element;
    this.dragging = false;

    element.draggable = true;

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
    if(!options.no_mouse)
    {
        this.handlers.push(element.on("mousedown", this.mousedown_event));
        this.handlers.push(element.on("dragstart", this.dragstart_event));
    }

    if(!options.no_touch)
    {
        this.handlers.push(element.on("touchstart", this.touchstart_event));
        this.handlers.push(element.on("touchmove", this.touchmove_event));
    }

    /*
     * We may or may not get a click event after mouseup.  This is a pain: if we get a
     * click event, we need to cancel it if we dragged, but we may not get a click event
     * at all; detecting whether a click event came from the drag or not is difficult.
     * Cancelling mouseup has no effect.  FF, IE7 and Opera still send the click event
     * if their dragstart or mousedown event is cancelled; WebKit doesn't.
     */
    if(navigator.userAgent.indexOf("AppleWebKit/") != -1)
        this.handlers.push(element.on("click", this.click_event));
}

DragElement.prototype.destroy = function()
{
    this.stop_dragging(null, true);
    for(var i = 0; i < this.handlers.length; ++i)
        this.handlers[i].stop();
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
    {
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
}

DragElement.prototype.mousemove_event = function(event)
{
    event.stopPropagation();
    event.preventDefault();
    
    var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
    var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);

    var x = event.pageX - scrollLeft;
    var y = event.pageY - scrollTop;
    this.handle_move_event(event, x, y);
}

DragElement.prototype.touchmove_event = function(event)
{
    /* Ignore touches other than the one we started with. */
    var touch = null;
    for(var i = 0; i < event.changedTouches.length; ++i)
    {
        var t = event.changedTouches[i];
        if(t.identifier == this.dragging_touch_identifier)
        {
            touch = t;
            break;
        }
    }
    if(touch == null)
        return;

    event.preventDefault();

    /* If a touch drags over the bottom navigation bar in Safari and is released while outside of
     * the viewport, the touchend event is never sent.  Work around this by cancelling the drag
     * if we get too close to the end.  Don't do this if we're in standalone (web app) mode, since
     * there's no navigation bar. */
    if(!window.navigator.standalone && touch.pageY > window.innerHeight-10)
    {
        debug("Dragged off the bottom");
        this.stop_dragging(event, true);
        return;
    }

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
            if(this.options.onstartdrag({ handler: this, latest_event: event, x: x, y: y }))
            {
                this.dragging = false;
                return;
            }
        }

        this.dragged = true;
        
        document.body.setAttribute("dragging", this.overriden_drag_class || "1");
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
    if(event.button != 0)
        return;

    /* Check if we're temporarily ignoring mouse events. */
    if(this.ignore_mouse_events_until != null)
    {
        var now = (new Date()).valueOf();
        if(now < this.ignore_mouse_events_until)
            return;

        this.ignore_mouse_events_until = null;
    }
    var scrollLeft = (window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft);
    var scrollTop = (window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop);
    var x = event.pageX - scrollLeft;
    var y = event.pageY - scrollTop;

    this.start_dragging(event, false, x, y, 0);
}

DragElement.prototype.touchstart_event = function(event)
{
    /* If we have multiple touches, find the first one that actually refers to us. */
    var touch = null;
    for(var i = 0; i < event.changedTouches.length; ++i)
    {
        var t = event.changedTouches[i];
        if(!t.target.isParentNode(this.element))
            continue;
        touch = t;
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
    if(this.dragging_touch_identifier != null)
        return;

    /* If we've been started with a touch event, only listen for touch events.  If we've
     * been started with a mouse event, only listen for mouse events.  We may receive
     * both sets of events, and the anchor coordinates for the two may not be compatible. */
    this.drag_handlers.push(window.on("pagehide", this.pagehide_event.bind(this)));
    if(touch)
    {
        this.drag_handlers.push(document.on("touchend", this.touchend_event));
        this.drag_handlers.push(document.on("touchcancel", this.touchend_event));
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

    if(this.options.ondown)
    {
        this.options.ondown({
            dragger: this,
            x: x,
            y: y,
            latest_event: event
        });
    }
}

DragElement.prototype.pagehide_event = function(event)
{
    this.stop_dragging(event, true);
}

DragElement.prototype.touchend_event = function(event)
{
    /* If our touch was released, stop the drag. */
    for(var i = 0; i < event.changedTouches.length; ++i)
    {
        var t = event.changedTouches[i];
        if(t.identifier == this.dragging_touch_identifier)
        {
            this.stop_dragging(event, event.type == "touchcancel");

            /*
             * Work around a bug on iPhone.  The mousedown and mouseup events are sent after
             * the touch is released, instead of when they should be (immediately following
             * touchstart and touchend).  This means we'll process each touch as a touch,
             * then immediately after as a mouse press, and fire ondown/onup events for each.
             *
             * We can't simply ignore mouse presses if touch events are supported; some devices
             * will support both touches and mice and both types of events will always need to
             * be handled.
             *
             * After a touch is released, ignore all mouse presses for a little while.  It's
             * unlikely that the user will touch an element, then immediately click it.
             */
            this.ignore_mouse_events_until = (new Date()).valueOf() + 500;
            return;
        }
    }
}

DragElement.prototype.mouseup_event = function(event)
{
    if(event.button != 0)
        return;

    this.stop_dragging(event, false);
}

/* If cancelling is true, we're stopping for a reason other than an explicit mouse/touch
 * release. */
DragElement.prototype.stop_dragging = function(event, cancelling)
{
    if(this.dragging)
    {
        this.dragging = false;
        document.body.removeAttribute("dragging");

        if(this.options.onenddrag)
            this.options.onenddrag(this);
    }

    for(var i = 0; i < this.drag_handlers.length; ++i)
        this.drag_handlers[i].stop();
    this.drag_handlers = [];
    this.dragging_touch_identifier = null;

    if(this.options.onup)
        this.options.onup({
            dragger: this,
            latest_event: event,
            cancelling: cancelling
        });
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

