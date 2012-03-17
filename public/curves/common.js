"use strict";

if(!Function.prototype.bind)
{
    Function.prototype.bind = function(context)
    {
        var self = this;
        var args = Array.prototype.slice.call(arguments, 1);

        return function()
        {
            array = Array.prototype.slice.call(args, 0);
            var a = args.concat([].slice.call(arguments));

            return self.apply(context, a);
        }
    }
}

Element.prototype.isParentOf = function(element)
{
    var parent = this;
    while(element)
    {
        if(parent == element)
            return true;
        element = element.parentNode;
    }
    return false;
};

/* Generate primarymouseup and primarymousedown events.  These are dispatched
 * before mouseup and mousedown when button == 0.  If these events are cancelled,
 * mouseup/mousedown will be prevented. */
(function() {
    /* Given a mouse event, dispatch a new mouse event with the specified
     * type to the same target.  If preventDefault is called on that event,
     * cancel the original event as well. */
    var dispatchMouseEvent = function(type, original_event)
    {
        var event = document.createEvent("Event");
        event.initEvent(type, true, true);

        var copy = [
            "altKey", "ctrlKey", "shiftKey", "metaKey", "button",
            "mozInputSource", "mozPressure",
            "clientX", "clientY",
            "layerX", "layerY",
            "pageX", "pageY",
            "screenX", "screenY"
        ];
        for(var i = 0; i < copy.length; ++i)
        {
            event[copy[i]] = original_event[copy[i]];
        }
        event.buttons = 0;
        event.relatedTarget = null;

        var result = original_event.target.dispatchEvent(event);
        if(!result)
        {
            original_event.stopPropagation();
            original_event.preventDefault();
        }
        return result;
    }

    window.addEventListener("mousedown", function(e) {
        if(e.button == 0)
            dispatchMouseEvent("primarymousedown", e);
    }, true);

    window.addEventListener("mouseup", function(e) {
        if(e.button == 0)
            dispatchMouseEvent("primarymouseup", e);
    }, true);
})();

var copy_attributes = function(to, from, keys)
{
    for(var i = 0; i < keys.length; ++i)
        to[keys[i]] = from[keys[i]];
};

/* Implement the DOM "wheel" event based on the mousewheel or DOMMouseScroll event. */
(function() {
    var scroll = function(e) {
        var event = document.createEvent("Event");
        event.initEvent("wheel", true, true);

        var copy = [
            "altKey", "ctrlKey", "shiftKey", "metaKey",
            "mozInputSource", "mozPressure",
            "clientX", "clientY",
            "layerX", "layerY",
            "pageX", "pageY",
            "screenX", "screenY"
        ];
	copy_attributes(event, e, copy);

        event.buttons = 0;
        event.relatedTarget = null;
        event.deltaX = event.deltaY = event.deltaZ = 0;

        if(e.type == "DOMMouseScroll")
        {
            if(!("axis" in e) || e.axis == e.VERTICAL_AXIS)
                event.deltaY = e.detail / 3;
            else if(e.axis == e.HORIZONTAL_AXIS)
                event.deltaX = e.detail / 3;
        }
        else if(e.type == "mousewheel")
        {
            event.deltaY = -e.wheelDelta / 120;
        }

        if(!e.target.dispatchEvent(event))
        {
            e.stopPropagation();
            e.preventDefault();
        }
    }

    if("onmousewheel" in window)
    {
        window.addEventListener("mousewheel", scroll, true);
    }
    else
    {
        window.addEventListener("DOMMouseScroll", scroll, false);
    }
})();

function offsetFromRoot(element)
{
    var x = 0, y = 0;
    while(element)
    {
        x += element.offsetLeft;
        y += element.offsetTop;
        element = element.offsetParent;
    }
    return [x, y];
}

var toHex = function(val)
{
    val = val.toString(16);
    if(val.length == 1)
        val = "0" + val;
    return val.toUpperCase();
}

/* window.encodeURIComponent will escape much more than necessary, which
 * will uglify things like URLs in query parameters. */
var encodeURILight = function(s)
{
    return s.replace(/%/g, "%25").replace(/\?/g, "%3f");
}

var parseQueryParameters = function(query)
{
    if(query == "")
      return {};
    if(query[0] == "?")
        query = query.substr(1);
    var params = {};
    var query_parameters = query.split("&");
    for(var i = 0; i < query_parameters.length; ++i)
    {
        var keyval = query_parameters[i]; /* a=b */
        var key = keyval.split("=", 1)[0];

        var value = keyval.substr(key.length+1);
        key = window.decodeURIComponent(key);
        value = window.decodeURIComponent(value);
        params[key] = value;

    }
    return params;
};

Element.prototype.on = function(type, handler, options)
{
    if(!options)
        options = {};
    var useCapture = options.useCapture;
    this.addEventListener(type, handler, useCapture);
    return {
        stop: function()
        {
            console.log("stop");
            this.removeEventListener(type, handler, useCapture);
        }.bind(this)
    }
};
window.on = Document.prototype.on = Element.prototype.on;

var position_relative_to_element = function(element, x, y)
{
    var element_offset = offsetFromRoot(element);
    return {
        dx: x - element_offset[0],
        dy: y - element_offset[1]
    };
};

/* On wheel events, send a wheelfocus event to the element that has focused,
 * regardless of where the mouse cursor is.  If that event is canceled, cancel
 * the wheel event. */
(function() {
    var focused_element = null;

    document.addEventListener("focus", function(e) {
        focused_element = e.target;
    }.bind(this), true);

    document.addEventListener("blur", function(e) {
        focused_element = null;
    }.bind(this), true);

    document.addEventListener("wheel", function(e) {
        if(focused_element == null)
            return;

        var event = document.createEvent("Event");
        event.initEvent("wheelfocus", true, true);

        copy_attributes(event, e, [
            "altKey", "ctrlKey", "shiftKey", "metaKey",
            "deltaX", "deltaY", "deltaZ",
            "clientX", "clientY",
            "layerX", "layerY",
            "pageX", "pageY",
            "screenX", "screenY"
        ]);

        var result = focused_element.dispatchEvent(event);
        if(!result)
        {
            e.stopPropagation();
            e.preventDefault();
        }
    }.bind(this), true);
})();

if(!("console" in window))
{
    window.console = {
        log: function() {
        }
    };
}

/* Why is URL prefixed on WebKit? */
if(!("URL" in window) && "webkitURL" in window)
    window.URL = window.webkitURL;

