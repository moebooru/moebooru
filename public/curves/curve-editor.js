"use strict";

var CurveEditor = function(container)
{
    this.container = container;
    this.onchange = function() { }
    this.oncurvechanged = function() { }
    this.canvas_container = this.container.getElementsByClassName("canvas-box")[0];
    this.canvas = this.container.getElementsByClassName("curve-canvas")[0];
    this.handle_container = this.container.getElementsByClassName("curves-handle-box")[0];
    this.handle_template = this.container.getElementsByClassName("curves-handle-template")[0];
    this.drag_axes = this.container.getElementsByClassName("drag-axes")[0];
    this.point_input = this.container.getElementsByClassName("point-input")[0];
    this.point_output = this.container.getElementsByClassName("point-output")[0];
    this.curve_reference_horizontal = this.container.getElementsByClassName("curve-reference-horizontal")[0];
    this.horizontal_drag_box = this.container.getElementsByClassName("curve-horizontal-drag-box")[0];
    this.blackpoint_marker = this.container.getElementsByClassName("blackpoint-marker")[0];
    this.whitepoint_marker = this.container.getElementsByClassName("whitepoint-marker")[0];
    this.acv_save = this.container.getElementsByClassName("acv-save")[0];
    this.acv_load = this.container.getElementsByClassName("acv-load")[0];
    this.acv_load_input = this.container.getElementsByClassName("acv-load-input")[0];
    this.reset_button = this.container.getElementsByClassName("reset-button")[0];

    this.container_mousedown = this.container_mousedown.bind(this);
    this.window_keydown = this.window_keydown.bind(this);
    this.window_mouseup = this.window_mouseup.bind(this);
    this.container_mousemove = this.container_mousemove.bind(this);
    this.container_mouseout = this.container_mouseout.bind(this);
    this.container_wheelfocus = this.container_wheelfocus.bind(this);
    this.acv_load_input_change = this.acv_load_input_change.bind(this);
    this.value_box_input = this.value_box_input.bind(this);
    this.value_box_focus = this.value_box_focus.bind(this);
    this.value_box_blur = this.value_box_blur.bind(this);

    this.window_mousemove = this.window_mousemove.bind(this);
    this.window_pagehide = this.window_pagehide.bind(this);

    this.selection_handles = [];
    this.selected_handle_idx = null;
    this.last_mouse_cx = null;
    this.last_mouse_cy = null;
    this.dragging = false;
    this.render_size = 249;
    this.max_distance_to_create_new_point = 30;

    /* Scale from [0,255] to CSS coordinates, [0,248]. */
    this.render_scale = (this.render_size-1)/255;

    /* Scale from [0,255] to canvas coordinates, [0,249]. */
    this.render_scale_canvas = this.render_size/255;

    window.addEventListener("keydown", this.window_keydown, false);
    this.canvas_container.addEventListener("mousemove", this.container_mousemove, false);
    this.canvas_container.addEventListener("mouseout", this.container_mouseout, false);
    this.canvas_container.addEventListener("primarymousedown", this.container_mousedown, false);
    this.container.addEventListener("wheelfocus", this.container_wheelfocus, false);

    var init_value_box = function(box)
    {
        box.addEventListener("input", this.value_box_input, false);
        box.addEventListener("focus", this.value_box_focus, false);
        box.addEventListener("blur", this.value_box_blur, false);
    }.bind(this);
    init_value_box(this.point_input);
    init_value_box(this.point_output);

    /* Set up the "Save" link. */
    this.acv_load_input.addEventListener("change", this.acv_load_input_change, false);
    this.acv_load.addEventListener("click", function(e) {
        e.preventDefault();
        this.acv_load_input.click();
    }.bind(this), false);

    /* Set up the "reset" link. */
    this.reset_button.addEventListener("click", function(e) {
        e.preventDefault();

        this.reset_curve();
        this.save_undo_state();
        this.update();
    }.bind(this), false);

    /* Set up clicking and dragging on the horizontal reference bar. */
    var set_handle_from_drag_event = function(e)
    {
        var mouse_pos = this.get_mouse_position(e.latest_event);
        this.set_point_to(mouse_pos.cx, null, this.selected_handle_idx);

        this.update_position_boxes();
        this.update();
    }.bind(this);
    new DragElement(this.horizontal_drag_box, {
        snap_pixels: 0,

        ondown: function(e) {
            /* When clicking the horizontal reference bar, select the closer of the first
             * and last curve handles. */
            var mouse_pos = this.get_mouse_position(e.latest_event);
            var black_x = this.active_curve.points[0].x;
            var white_x = this.active_curve.points[this.active_curve.points.length-1].x;

            if(Math.abs(mouse_pos.cx - white_x) < Math.abs(mouse_pos.cx - black_x))
                this.select_handle(this.active_curve.points.length-1);
            else
                this.select_handle(0);

            set_handle_from_drag_event(e);
        }.bind(this),

        /* Hide the cursor while dragging the horizontal handles. */
//        onstartdrag: function(e) { document.documentElement.setAttribute("cursor", "none"); }.bind(this),
//        onenddrag: function(e) { document.documentElement.removeAttribute("cursor"); }.bind(this),

        ondrag: function(e)
        {
            set_handle_from_drag_event(e);
        }.bind(this)
    });

    this.ctx = this.canvas.getContext("2d");
    if(!this.ctx)
    {
        console.log("Couldn't open a canvas context");
        return;
    }

    this.active_curve_idx = 0;

    /* Create the four curves. */
    this.reset_curve();

    this.save_undo_state();

    this.select_curve(0);
}

CurveEditor.prototype.__defineGetter__("active_curve", function() {
    return this.curves[this.active_curve_idx];
});
CurveEditor.prototype.__defineSetter__("active_curve", function(val) {
    throw "read-only attribute";
});

/* Reset all curves to their default.  If empty is true, the created
 * curves will have no points and at least two points must be created;
 * if false, they will be initialized with (0, 0) and (255, 255). */
CurveEditor.prototype.reset_curve = function(empty)
{
    this.selected_handle_idx = null;

    this.curves = [];
    for(var i = 0; i < 4; ++i)
        this.curves.push(new Interpolation(empty));

    this.recreate_handles();
    this.update_position_boxes();
}

/* Update the curve to reflect the value in the specified value box. */
CurveEditor.prototype.update_from_value_box = function(element)
{
    if(this.selected_handle_idx == null)
        return;
    var is_input = element == this.point_input;
    var value = element.value;
    value = parseInt(value);

    /* If the value is invalid, let the user keep typing but don't update
     * the curve. */
    if(isNaN(value))
        return;

    var x = is_input? value:null;
    var y = !is_input? value:null;
    var result = this.set_point_to(x, y, this.selected_handle_idx);

    this.update();

    /* We save undo states when the box loses focus, not as the user types. */
}

CurveEditor.prototype.value_box_input = function(e)
{
    this.update_from_value_box(e.target);
}

CurveEditor.prototype.value_box_focus = function(e)
{
    this.save_undo_state();
}

CurveEditor.prototype.value_box_blur = function(e)
{
    /* When a value box loses focus, update it with the actual value we
     * used; this will fill in invalid values. */
    this.update_position_boxes();
    this.save_undo_state();
}

/* Create curve handles for the selected curve. */
CurveEditor.prototype.recreate_handles = function()
{
    /* Delete all handles. */
    while(this.handle_container.firstChild)
        this.handle_container.removeChild(this.handle_container.firstChild);
    this.selection_handles = [];

    /* Create the handles for the selected curve. */
    for(var i = 0; i < this.active_curve.points.length; ++i)
        this.create_handle(i);

    this.position_handles();
}

CurveEditor.prototype.position_handles = function()
{
    /* The curve LUT always has 256 points, but we render to a different size in
     * order to be able to draw precise grid lines.  Scale the data to the size
     * we're rendering it at. */
    var render_points = [];
    for(var i = 0; i < this.active_curve.points.length; ++i)
    {
        var p = this.active_curve.points[i];
        render_points.push(new Point(p.x*this.render_scale, (255-p.y)*this.render_scale));
    }
    /* Update the handle positions. */
    var handle = this.handle_container.firstChild;
    if(this.active_curve.points.length != this.selection_handles.length)
        throw "Internal error: handles mismatched from curve size";

    for(var idx = 0; idx < this.selection_handles.length; ++idx)
    {
        var handle = this.selection_handles[idx];
        var render_point = render_points[idx];
        var point = this.active_curve.points[idx];

        /* If the point is disabled because it's been dragged out of bounds, don't
         * render the handle. */
        handle.hidden = point.disabled;

        handle.style.left = render_point.x + "px";
        handle.style.top = render_point.y + "px";
    }

    /* Position the markers under the horizontal reference.  These aren't actually
     * handles, but they're updated whenever handles are. */
    if(this.active_curve.points.length >= 2)
    {
        var render_point = render_points[0];
        this.blackpoint_marker.style.left = render_point.x + "px";

        var render_point = render_points[render_points.length-1];
        this.whitepoint_marker.style.left = render_point.x + "px";
    }
}


/* We have four curves: master, R, G, B.  Select the primary curve, and
 * update the drag handles to reflect it. */
CurveEditor.prototype.select_curve = function(idx)
{
    if(this.active_curve_idx == idx)
        return;

    this.select_handle(null);
    this.active_curve_idx = idx;

    this.recreate_handles();

    /* Update the displayed curve and the handle positions. */
    this.update();

    this.oncurvechanged(this);
}

/*
 * Set the specified point's position.  The coordinates will be clamped to
 * valid values.  The point will be clamped to the nearest valid position.
 *
 * If either of x or y are null, that value will be left unchanged.
 *
 * Value boxes (point_input, point_output) are not updated, since that's not
 * wanted when the change itself is due to user input in those input boxes.
 */
CurveEditor.prototype.set_point_to = function(x, y, idx)
{
    var next_point = null, prev_point = null;
    var new_point = false;
    if(idx == null)
    {
        var idx_new = this.active_curve.set_point(x, y);
        idx = idx_new[0];
        new_point = idx_new[1];
    }

    var point = this.active_curve.points[idx];
    var next_point = this.active_curve.points[idx+1];
    var prev_point = this.active_curve.points[idx-1];
    if(x == null)
        x = point.x;
    if(y == null)
        y = point.y;

    /* Don't let points get too close to neighboring points. */
    var min_x = prev_point? (prev_point.x + 4):0;
    var max_x = next_point? (next_point.x - 4):255;

    if(new_point)
    {
        if(min_x > max_x)
        {
            /* The user tried to create a point, but there's no room between the
             * surrounding points to place one. */
            this.active_curve.points.splice(idx, 1);
            return null;
        }

        this.create_handle(idx);
    }

    point.x = x;
    point.y = y;
    // console.log("drag to", point.x + "x" + point.y);

    var out_of_bounds = 
        point.x < min_x || point.x > max_x ||
        point.y < -5 || point.y > 260;

    /* Clamp the output values. */
    point.x = Math.min(point.x, max_x);
    point.x = Math.max(point.x, min_x);
    point.y = Math.min(point.y, 255);
    point.y = Math.max(point.y, 0);

    return {
        point: point,
        idx: idx,
        out_of_bounds: out_of_bounds,
        new_point: new_point
    };
}


CurveEditor.prototype.update_position_boxes = function()
{
    /* Work around a Firefox bug: if we disable an input while it has focus,
     * all browser input breaks until the window is clicked. */
    if(this.selected_handle_idx == null)
    {
        this.point_input.blur();
        this.point_output.blur();
    }

    this.point_input.disabled = (this.selected_handle_idx == null);
    this.point_output.disabled = (this.selected_handle_idx == null);

    /* If no handle is selected, then point_input and point_output display the
     * cursor position. */
    if(this.selected_handle_idx == null)
    {
        this.point_input.value = this.last_mouse_cx == null? "":this.last_mouse_cx;
        this.point_output.value = this.last_mouse_cy == null? "":this.last_mouse_cy;
        return;
    }

    var point = this.active_curve.points[this.selected_handle_idx];
    this.point_input.value = point.disabled? "":point.x;
    this.point_output.value = point.disabled? "":point.y;
}

CurveEditor.prototype.select_handle = function(idx)
{
    if(idx == this.selected_handle_idx)
        return;

    if(this.selected_handle_idx != null)
    {
        var old_handle = this.selection_handles[this.selected_handle_idx];
        old_handle.removeAttribute("selected");
    }

    this.selected_handle_idx = idx;

    if(idx != null)
    {
        var handle = this.selection_handles[idx];
        handle.setAttribute("selected", "1");
    }

    this.update_position_boxes();
}

CurveEditor.prototype.get_handle_idx = function(handle)
{
    for(var i = 0; i < this.selection_handles.length; ++i)
    {
        if(this.selection_handles[i] == handle)
            return i;
    }
    return -1;
}

CurveEditor.prototype.container_mousedown = function(e)
{
    e.preventDefault();

    if(e.ctrlKey)
    {
        /* Delete handles on control-click. */
        if(e.target.isCurveHandle)
        {
            var handle_idx = this.get_handle_idx(e.target);
            if(handle_idx != -1)
            {
                this.delete_handle_idx(handle_idx);
                this.save_undo_state();
            }
        }
        return;
    }

    if(e.target.isCurveHandle)
    {
        var handle_idx = this.get_handle_idx(e.target);
        this.select_handle(handle_idx);
        console.log("Selected handle " + this.selected_handle_idx);
    }
    else
    {
        /* The click isn't on a handle.  If the click is close to the curve, create
         * a new point.  Otherwise, deselect any selected point. */
        var mouse_pos = this.get_mouse_position(e);
        if(!this.mouse_position_close_to_curve(mouse_pos))
        {
            /* It's far away, so just deselect any selected handles and stop. */
            this.select_handle(null);
            return;
        }

        /* The click is near the curve.  Create a new point. */
        var result = this.set_point_to(mouse_pos.cx, mouse_pos.cy);
        this.select_handle(result.idx);

        // console.log("new point", result.idx, mouse_pos.cx + "x" + mouse_pos.cy);

        /* Update to display the new point. */
        this.update();
    }

    this.start_dragging(e);
}

CurveEditor.prototype.window_keydown = function(e)
{
    if(e.ctrlKey && e.keyCode == 90) // ^Z
    {
        e.preventDefault();
        e.stopPropagation();
        this.undo();
        return;
    }
    if(e.altKey && e.keyCode >= 50 && e.keyCode <= 53) // '0'-'3'
    {
        e.preventDefault();
        e.stopPropagation();

        var selected_channel = e.keyCode - 50;

        console.log("Selected curve channel", selected_channel);
        this.select_curve(selected_channel);

        /* Save state after changing curves, so if a change is made and then undone,
         * we don't restore to a state on the previous curve.  Make this change permanent,
         * since it's weird for an undo to change channels. */
        this.save_undo_state(true);
    }
}

CurveEditor.prototype.window_mouseup = function(e)
{
    if(e.button != 0)
        return;
    this.stop_dragging();
}

/* Given a mouse event, return the offset from the top-left of the
 * canvas container of the event, and the corresponding [0,255] curve
 * value. */
CurveEditor.prototype.get_mouse_position = function(e)
{
    /* Figure out the mouse position within the canvas. */
    var cursorX = e.clientX;
    var cursorY = e.clientY;
    var container_offset = offsetFromRoot(this.canvas_container);
    var dx = cursorX - container_offset[0];
    var dy = cursorY - container_offset[1];

    /* Convert the delta from screen coordinates to the curve's
     * coordinates, [0,255]. */
    var cx = dx / this.render_scale;
    var cy = dy / this.render_scale;

    cy = 255-cy;

    cx = Math.round(cx);
    cy = Math.round(cy);

    return {
        dx: dx, dy: dy,
        cx: cx, cy: cy
    }
}

CurveEditor.prototype.mouse_position_close_to_curve = function(mouse_pos)
{
    var interp = this.active_curve.getInterpolationData();
    var y = interp.getYfromX(mouse_pos.cx);
    var distance = Math.abs(mouse_pos.cy - y);
    return distance <= this.max_distance_to_create_new_point;
}

/* Set the displayed input and output values to the cursor position.
 * This isn't done in window_mousemove, since that event is only active
 * when dragging. */
CurveEditor.prototype.container_mousemove = function(e)
{
    /* Set draggablePoint if the cursor is near the curve. */
    var mouse_pos = this.get_mouse_position(e);
    if(this.mouse_position_close_to_curve(mouse_pos))
        this.canvas_container.setAttribute("draggablePoint", "1");
    else
        this.canvas_container.removeAttribute("draggablePoint");
    
    this.last_mouse_cx = mouse_pos.cx;
    this.last_mouse_cy = mouse_pos.cy;
    this.update_position_boxes();
}

CurveEditor.prototype.container_mouseout = function(e)
{
    this.last_mouse_cx = null;
    this.last_mouse_cy = null;
    this.update_position_boxes();
}

/* This is fired when the mousewheel is used to change the selected value. */
CurveEditor.prototype.container_wheelfocus = function(e)
{
    var element = document.elementFromPoint(e.pageX, e.pageY);
    if(!this.container.isParentOf(element))
        return;

    if(e.target != this.point_input && e.target != this.point_output)
        return;

    e.preventDefault();
    e.stopPropagation();

    var elem = e.target;
    var value = parseInt(elem.value);
    var delta = e.deltaY > 0? -1:+1;
    if(e.shiftKey)
        delta *= 10;
    
    value += delta;
    elem.value = value;

    /* Update the curve from the new value. */
    this.update_from_value_box(elem);

    /* Our value may have been clamped, so update the box with the value that
     * was actually used. */
    this.update_position_boxes();
}

CurveEditor.prototype.window_mousemove = function(e)
{
    var mouse_pos = this.get_mouse_position(e);

    var result = this.set_point_to(mouse_pos.cx, mouse_pos.cy, this.selected_handle_idx);

    /* If the point is out of bounds, hide it.  Hidden points are removed when the
     * drag ends. The first and last points can't be removed by dragging. */
    if(result.idx > 0 && result.idx < this.active_curve.points.length - 1)
        result.point.disabled = result.out_of_bounds;

    document.body.setAttribute("cursor", result.out_of_bounds?"crosshair":"none");

    this.update_position_boxes();

    /* Position the drag axes.  Only display it if the point is in bounds; if we've
     * disabled the point, hide them. */
    this.drag_axes.hidden = result.out_of_bounds;
    this.drag_axes.style.left = mouse_pos.dx + "px";
    this.drag_axes.style.top = mouse_pos.dy + "px";

    /* Update the display. */
    this.update();
}

CurveEditor.prototype.window_pagehide = function(e)
{
    this.stop_dragging();
}

CurveEditor.prototype.start_dragging = function(e)
{
    this.dragging = true;
    var handle = this.selection_handles[this.selected_handle_idx];
    handle.setAttribute("dragging", "1");
    this.canvas_container.setAttribute("dragging", "1");
    document.body.setAttribute("cursor", "none");
    window.addEventListener("mouseup", this.window_mouseup, true);
    window.addEventListener("mousemove", this.window_mousemove, false);
    window.addEventListener("pagehide", this.window_pagehide, false);
}

CurveEditor.prototype.stop_dragging = function()
{
    if(!this.dragging)
        return;

    var handle = this.selection_handles[this.selected_handle_idx];
    handle.removeAttribute("dragging");
    this.canvas_container.removeAttribute("dragging");
    document.body.removeAttribute("cursor");
    window.removeEventListener("mouseup", this.window_mouseup, true);
    window.removeEventListener("mousemove", this.window_mousemove, false);
    window.removeEventListener("pagehide", this.window_pagehide, false);

    /* If the point was disabled, delete it. */
    var dragging_point = this.active_curve.points[this.selected_handle_idx];
    if(dragging_point.disabled)
    {
        console.log("deleting point");
        this.delete_handle_idx(this.selected_handle_idx);
    }

    this.drag_axes.hidden = true;
    this.dragging = false;

    console.log("stopped dragging; saving state");
    this.save_undo_state();
}

/* When a file is selected by clicking Load, read it and load it as
 * an ACV file. */
CurveEditor.prototype.acv_load_input_change = function(e)
{
    if(this.acv_load_input.files.length == 0)
        return;
    var file = this.acv_load_input.files[0];

    /* FF4 doesn't support readAsArrayBuffer. */
    var reader = new FileReader();
    reader.readAsBinaryString(file);
    reader.onerror = function(e)
    {
        alert("Couldn't load " + file.filename + ": " + reader.error.code);
    }.bind(this);

    reader.onload = function()
    {
        var data = this.parseACV(reader.result);
        if(data == null)
        {
            alert("Selected file is not a valid .ACV");
            return;
        }
        this.loadCurveData(data);
    }.bind(this);
}

CurveEditor.prototype.create_handle = function(idx)
{
    var handle = this.handle_template.cloneNode(true);
    handle.isCurveHandle = true;

    var channel_names = ["rgb", "red", "green", "blue"];
    handle.className += " " + channel_names[this.active_curve_idx];

    this.handle_container.appendChild(handle);
    this.selection_handles.splice(idx, 0, handle);
    if(this.selected_handle_idx != null && this.selected_handle_idx >= idx)
        ++this.selected_handle_idx;
    return handle;
}

CurveEditor.prototype.get_lut_with_scaling = function(idx)
{
    var lut = this.curves[idx].get_lut();
    var render_lut = [];
    for(var i = 0; i < lut.length; ++i)
    {
        var y = lut[i];
        y = 255-y;
        y *= this.render_scale_canvas;
        render_lut.push(y);
    }

    return {
        lut: lut,
        render_lut: render_lut
    }
}
CurveEditor.prototype.draw_curve_into_canvas = function(idx, update_cursor_map)
{
    var channel_colors = ["#000000", "#FF0000", "#00FF00", "#0000FF"];
    this.ctx.strokeStyle = channel_colors[idx];

    var lut = this.get_lut_with_scaling(idx);

    /* Draw the curve as a series of line segments. */
    this.ctx.beginPath();
    for(var x = 0; x < 256; ++x)
        this.ctx.lineTo(x*this.render_scale_canvas, lut.render_lut[x]);
    this.ctx.stroke();
}

/* Return an .ACV (Photoshop Curves preset) for the current curve. */
CurveEditor.prototype.getACV = function()
{
    var data = "";
    var append = function(val) { data += String.fromCharCode(val) }

    append(0); append(4); // version

    /* If the RGB channels are all unity, then we don't have to write them; only
     * write the master curve. */
    var rgb_unity = this.curves[1].is_unity() && this.curves[2].is_unity() && this.curves[3].is_unity();
    var curve_count = rgb_unity? 1:4;
    append(0); append(curve_count);

    for(var i = 0; i < curve_count; ++i)
    {
        var curve = this.curves[i];
        append(0); append(curve.points.length);
        for(var j = 0; j < curve.points.length; ++j)
        {
            var point = curve.points[j];
            append(0); append(point.y);
            append(0); append(point.x);
        }
    }
    return data;
}

/* Given a string containing an .ACV file, return a decoded object compatible
 * with loadCurveData. */
CurveEditor.prototype.parseACV = function(acv)
{
    var invalid = {};

    try
    {
        var pos = 0;
        var get16 = function()
        {
            if(pos == acv.length)
                throw invalid;
            var high = acv.charCodeAt(pos++);
            var low = acv.charCodeAt(pos++);
            return (high << 8) | low;
        }
        var version = get16();
        if(version != 4)
            throw invalid;

        // One curve is a monochrome master curve.  Three curves is RGB.  Four or more
        // curves is a master curve with RGB.  However, two curves isn't defined.
        var curve_count = get16();
        if(curve_count == 0)
            throw invalid;

        /* Ignore any channels beyond 4; Photoshop always writes at least 5. */
        curve_count = Math.min(curve_count, 4);

        var data = {};
        for(var i = 0; i < curve_count; ++i)
        {
            var curve_points = get16();
            var points = [];
            for(var p = 0; p < curve_points; ++p)
            {
                var y = get16();
                var x = get16();
                points.push(toHex(x));
                points.push(toHex(y));
            }
            var mrgb = "mrgb";
            data[mrgb[i]] = points.join("");
        }
        return data;
    } catch(e) {
        if(e != invalid) throw e;
        return null;
    }
}

/* Get an object representing the current curve, suitable for storing
 * URL parameters. */
CurveEditor.prototype.getCurveData = function()
{
    var result = {};
    var curve_names = ["m", "r", "g", "b"];
    for(var i = 0; i < 4; ++i)
    {
        var curve = this.curves[i];
        if(curve.is_unity())
            continue;
        var coords = [];
        for(var j = 0; j < curve.points.length; ++j)
        {
            coords.push(toHex(curve.points[j].x));
            coords.push(toHex(curve.points[j].y));
        }
        result[curve_names[i]] = coords.join("");
    }
    return result;
}

/* Load a curve from an object returned from getCurveData. */
CurveEditor.prototype.loadCurveData = function(data)
{
    /* Remove any existing curve data.  Don't populate with default points, so
     * the default points won't cause our new points to be clamped. */
    this.reset_curve(true);

    var curve_names = ["m", "r", "g", "b"];
    for(var i = 0; i < 4; ++i)
    {
        var name = curve_names[i];
        var points = data[name];

        /* If the item doesn't exist, use the default. */
        if(!points)
        {
            this.curves[i].set_point(0, 0);
            this.curves[i].set_point(255, 255);
            continue;
        }

        if((points.length % 4) != 0)
        {
            console.warn("Invalid curve data: " + points);
            continue;
        }

        for(var j = 0; j < points.length; j += 4)
        {
            var x = parseInt(points[j+0] + points[j+1], 16);
            var y = parseInt(points[j+2] + points[j+3], 16);
            if(isNaN(x) || isNaN(y))
            {
                console.warn("Invalid curve data: " + points);
                break;
            }

            this.curves[i].set_point(x, y);
        }
    }

    this.recreate_handles();
    this.update_position_boxes();
    this.update();
}

/* Retrieve all undoable state. */
CurveEditor.prototype.get_state = function()
{
    return {
        curveData: this.getCurveData(),
        active_curve_idx: this.active_curve_idx,
        selected_handle_idx: this.selected_handle_idx
    }
}

CurveEditor.prototype.load_state = function(state)
{
    this.loadCurveData(state.curveData);
    this.select_curve(state.active_curve_idx);
    this.select_handle(state.selected_handle_idx);
}

var objects_identical = function(lhs, rhs)
{
    for(var key in lhs)
    {
        var l = lhs[key];
        var r = rhs[key];
        if(typeof(l) == "object" && typeof(r) == "object")
        {
            if(!objects_identical(l, r))
                return false;
        }
        else if(l != r)
            return false;
    }

    for(var key in rhs)
    {
        if(!(key in lhs))
            return false;
    }

    return true;
}

/* After making a change, save it to the undo history.  If permanent
 * is true, this change can't be undone. */
CurveEditor.prototype.save_undo_state = function(permanent)
{
    var current_state = this.get_state();
    var state_unchanged = true;
    if(this.current_state && objects_identical(current_state, this.current_state))
    {
        console.log("save_undo_state unchanged");
        return;
    }
    this.previous_state = permanent? null:this.current_state;
    this.current_state = current_state;
    /* console.log("saved undo");
    console.log("-> prev", this.previous_state);
    console.log("-> curr", this.current_state); */
}

/*
 * Undo the previous action.
 *
 * If the current state differs from the last call to save_undo_state, restore to
 * it.  Otherwise, restore to the call before it.
 *
 * This allows delaying saving undo states while typing in input boxes until the
 * box loses focus.  For example,
 *
 * a = 1; save_undo_state(); a = 2; undo();
 * > a == 1
 * a = 1; save_undo_state(); a = 2; save_undo_state(); undo();
 * > a == 1
 * a = 1; save_undo_state(); a = 2; save_undo_state(); a = 3; undo();
 * > a == 2
 */
CurveEditor.prototype.undo = function()
{
    var current_state = this.get_state();
 /*   console.log("Undo");
    console.log("Now", current_state);
    console.log("Cur", this.current_state);
    console.log("Prev", this.previous_state); */

    if(this.current_state && !objects_identical(current_state, this.current_state))
    {
        console.log("Restoring state from current_state");
        this.load_state(this.current_state);
        this.current_state = current_state;
        return;
    }

    if(this.previous_state)
    {
        console.log("Restoring state from previous_state");
        this.load_state(this.previous_state);
        this.current_state = this.previous_state;
        this.previous_state = current_state;
    }
}

CurveEditor.prototype.update = function()
{
    /* Update the download link with the current curve. */
    var url = "/download?filename=curve.acv&data=";
    url += btoa(this.getACV());
    this.acv_save.href = url;

    this.ctx.save();

    this.position_handles();
    this.ctx.clearRect(0, 0, this.canvas.offsetWidth, this.canvas.offsetHeight);

    /* Pad the edges.  The margins on .canvas-box and .canvas-box > .canvas
     * adjust for this. */
    this.ctx.translate(1, 1);

    /* Draw the grid. */
    this.ctx.strokeStyle = "#aaaaaa";
    for(var i = 1; i < 4; ++i)
    {
        this.ctx.beginPath();
        this.ctx.lineTo(i*62 + 0.5, -1);
        this.ctx.lineTo(i*62 + 0.5, this.render_size+1);
        this.ctx.stroke();

        this.ctx.beginPath();
        this.ctx.lineTo(-1, 62*i + 0.5);
        this.ctx.lineTo(this.render_size+1, 62*i + 0.5);
        this.ctx.stroke();
    }

    this.ctx.beginPath();
    this.ctx.lineTo(-1, this.render_size+1);
    this.ctx.lineTo(this.render_size+1, -1);
    this.ctx.stroke();
   
    if(this.active_curve_idx == 0)
    {
        /* When we're editing the master curve, show any channel curves that aren't
         * unity.  Always draw this under the active curve. */
        for(var i = 1; i <= 3; ++i)
        {
            var curve = this.curves[i];
            if(curve.is_unity())
                continue;
            this.draw_curve_into_canvas(i);
        }
    }

    this.draw_curve_into_canvas(this.active_curve_idx, true);

    this.ctx.restore();

    this.onchange();
}


CurveEditor.prototype.delete_handle_idx = function(idx)
{
    /* The first and last points can't be deleted. */
    if(idx == 0 || idx == this.active_curve.points.length - 1)
        return;

    /* If the handle that's being deleted is selected, unselect it. */
    if(this.selected_handle_idx == idx)
        this.select_handle(null);

    /* Remove the point. */
    var handle = this.selection_handles[idx];
    this.handle_container.removeChild(handle);
    this.active_curve.points.splice(idx, 1);
    this.selection_handles.splice(idx, 1);
    if(idx < this.selected_handle_idx)
        --this.selected_handle_idx;

    /* Update the display. */
    this.update();
};

/* Retrieve the 256x3 LUT for the current curves. */
CurveEditor.prototype.get_combined_lut = function(show_clipping, show_original)
{
    var lut = new Uint8Array(256*3);
    var main_lut = this.curves[0].get_lut(show_clipping);

    for(var i = 0; i < 3; ++i)
    {
        var combined_lut = [];
        if(show_original)
            combined_lut = this.curves[i+1].get_default_lut();
        else
        {
            var channel_lut = this.curves[i+1].get_lut(show_clipping);

            for(var x = 0; x < 256; ++x)
            {
                var v = Math.round(main_lut[x]);
                combined_lut.push(channel_lut[v]);
            }
        }
        
        if(show_clipping)
        {
            /* All clipped values are set to 1000.  Change all clipped values
             * to 255 and all others to 0. */
            for(var x = 0; x < 256; ++x)
                combined_lut[x] = (combined_lut[x] == 1000)? 255:0;
        }

        lut.set(new Uint8Array(combined_lut), 256*i);
    }
    return lut;
}

