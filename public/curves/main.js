var MainUI = function()
{
    this.image_load = this.image_load.bind(this);
    this.image_error = this.image_error.bind(this);
    this.curve_editor_onchange = this.curve_editor_onchange.bind(this);
    this.curve_editor_oncurvechanged = this.curve_editor_oncurvechanged.bind(this);
    this.canvas_mouse_down = this.canvas_mouse_down.bind(this);
    this.canvas_mouse_up = this.canvas_mouse_up.bind(this);
    this.load_file_input_change = this.load_file_input_change.bind(this);
    this.image_url_box_change = this.image_url_box_change.bind(this);
    this.load_url_link_click = this.load_url_link_click.bind(this);
    this.channel_select_change = this.channel_select_change.bind(this);

    var canvas = document.getElementById("display-canvas");
    canvas.addEventListener("primarymousedown", this.canvas_mouse_down, false);
    canvas.addEventListener("primarymouseup", this.canvas_mouse_up, false);

    this.renderer = new Renderer(canvas);

    var histogram_canvas = document.getElementById("histogram-canvas");
    this.histogram = new Histogram(histogram_canvas);

    this.showing_url = true;
    this.mouse_pressed = false;
    this.show_clipping = false;


/*var gl = this.renderer.gl;
var canvas = this.renderer.canvas;
canvas.addEventListener("webglcontextlost", function(e) {
    console.log("lost");
}.bind(this), false);*/
/*
    canvas.addEventListener("webglcontextrestored", function(e) {
        console.log("restored");
    }.bind(this), false);
    
document.getElementById("test").addEventListener("click", function(e) {
    e.stopPropagation();
    e.preventDefault();
    var ext = this.renderer.gl.getExtension("WEBKIT_lose_context");
    console.log("lost 1: " + this.renderer.gl.isContextLost());
    ext.loseContext();
}.bind(this), false);
*/
    this.image = document.createElement("img");
    this.image.src = "";
    this.image_url_needs_revocation = false;
    this.image.addEventListener("load", this.image_load, false);
    this.image.addEventListener("error", this.image_error, false);

    this.channel_select = document.getElementById("channel-select");
    this.channel_select.addEventListener("change", this.channel_select_change, false);

    this.image_url_box = document.getElementById("image-url-box");
    this.image_url_box.addEventListener("change", this.image_url_box_change, false);

    var load_file_input = document.getElementById("load-file-input");
    load_file_input.addEventListener("change", this.load_file_input_change, false);

    document.getElementById("load-file-link").addEventListener("click", function(event) {
        event.preventDefault();
        load_file_input.click();
    }, false);
    document.getElementById("image-filename-box").addEventListener("click", function(event) {
        event.preventDefault();
        load_file_input.click();
    }, false);
    document.getElementById("load-url-link").addEventListener("click", this.load_url_link_click, false);
    document.getElementById("show-clipping").addEventListener("change", function(e) {
        this.show_clipping = e.target.checked;
        this.update_display();
    }.bind(this), false);

    this.curve_editor = new CurveEditor(document.getElementById("curve-editor"));
    this.curve_editor.select_curve(0);
    this.curve_editor.onchange = this.curve_editor_onchange;
    this.curve_editor.oncurvechanged = this.curve_editor_oncurvechanged;
    this.curve_editor_oncurvechanged(this.curve_editor);

    window.addEventListener("popstate", function(e) { this.load_from_window_location(e.state); }.bind(this), false);
    this.load_from_window_location(null);

    this.update_address_bar();

    this.show_url(true);
}

/* Load settings from the query parameters, if any. */
MainUI.prototype.load_from_window_location = function(state)
{
    var params = parseQueryParameters(window.location.search);
    this.image_url_box.value = params.url || "";

    /* If this state was loaded using a file, load the file; otherwise load the URL.
     * Note that storing Files in history states is broken in Firefox, and in Chrome
     * they won't survive a tab restore, but this at least makes browser back/forward
     * work. */
    if(state && state.file)
        this.set_image_file(state.file);
    else
        this.set_image_url(this.image_url_box.value, false);

    /* Do this last, since loadCurveData will call onchange, which will set
     * update_address_bar.  If we havn't finished updating everything else,
     * it'll update the history state again with the old state. */
    this.curve_editor.loadCurveData(params);
    this.curve_editor.save_undo_state(true);
}

MainUI.prototype.image_load = function(event)
{
    console.log("Image loaded");
    this.renderer.loadTexture(this.image);
    this.histogram.load_texture(this.image);
    this.last_drawn_histogram_idx = null;

    // this.histogram.update();
    this.update_display();
}

MainUI.prototype.image_error = function(event)
{
    console.log("Error loading image");
    this.renderer.loadTexture(null);
    this.histogram.load_texture(null);
    this.last_drawn_histogram_idx = null;

    // this.histogram.update();
    this.update_display();
}

MainUI.prototype.curve_editor_oncurvechanged = function(editor)
{
    var channel_name = "MRGB"[editor.active_curve_idx];
    this.channel_select.value = channel_name;
}

MainUI.prototype.channel_select_change = function(event)
{
    var channel = this.channel_select.value;
    var channel_index = "MRGB".indexOf(channel);
    this.curve_editor.select_curve(channel_index);
}

/* When the contents of the URL input change, start loading the
 * image and update the address bar with the change. */
MainUI.prototype.image_url_box_change = function(event)
{
    this.set_image_url(this.image_url_box.value, false);
    this.update_address_bar(true);
}

/* When the "open a link" button is pressed, switch back to the
 * URL display and focus the input box. */
MainUI.prototype.load_url_link_click = function(event)
{
    this.show_url(true);
    this.image_url_box.focus();
    this.image_url_box.select();
}

/* Select whether the URL or file input display is visible. */
MainUI.prototype.show_url = function(show)
{
    this.showing_url = show;
    var load_url_box = document.getElementById("load-url-box");
    load_url_box.hidden = !this.showing_url;

    var load_file_box = document.getElementById("load-file-box");
    load_file_box.hidden = this.showing_url;
}

/* The user selected a file; begin loading it. */
MainUI.prototype.load_file_input_change = function(event)
{
    if(event.target.files.length == 0)
        return;

    this.set_image_file(event.target.files[0]);

    this.update_address_bar(true);
}

MainUI.prototype.set_image_file = function(file)
{
    this.current_file = file;

    /* Make sure the file selection input is visible. */
    this.show_url(false);

    var image_filename_box = document.getElementById("image-filename-box");
    image_filename_box.textContent = file.name;

    this.set_image_url(URL.createObjectURL(file), true);
}

MainUI.prototype.set_image_url = function(url, needs_revocation)
{
    /* Stop showing the old image immediately. */
    this.renderer.loadTexture(null);

    if(url == "")
        url = "about:blank";
    console.log(url);
    if(this.image_url_needs_revocation)
    {
        console.log("Revoked old URL");
        URL.revokeObjectURL(this.image.src);
        this.image_url_needs_revocation = false;
    }

    this.image.src = url;
    this.image_url_needs_revocation = needs_revocation;
}

/* This is called when the curve in the editor is changed.  Update the
 * image display. */
MainUI.prototype.curve_editor_onchange = function()
{
    this.update_address_bar();
    this.update_display();
}

MainUI.prototype.update_display = function()
{
    /* Read the curves LUT from each channel and pass it to the this.renderer. */
    var lut = this.curve_editor.get_combined_lut(this.show_clipping && !this.mouse_pressed, this.mouse_pressed);

    /* Send the LUT to the this.renderer. */
    this.renderer.lutTextureSet(lut);

    /* Render the image with the updated curves. */
    this.renderer.draw();

    if(this.last_drawn_histogram_idx != this.curve_editor.active_curve_idx)
    {
	this.last_drawn_histogram_idx = this.curve_editor.active_curve_idx;
        this.histogram.set_channel(this.curve_editor.active_curve_idx);
        this.histogram.draw();
    }
}

/* Update the address bar to reflect the current state. */
MainUI.prototype.update_address_bar = function(push)
{
    var url = window.location.protocol + "//" + window.location.host + window.location.pathname + "?";
    var curve_data = this.curve_editor.getCurveData();
    var parts = [];
    if(this.showing_url && this.image_url_box.value != "")
        parts.push("url=" + encodeURILight(this.image_url_box.value));
    var data = {};
    if(!this.showing_url)
    {
        console.log("saved file to state", this.current_file);
        data.file = this.current_file;
    }

    for(var key in curve_data)
        parts.push(key + "=" + curve_data[key]);
    url += parts.join("&");

    if(push)
        history.pushState(data, window.title, url);
    else
        history.replaceState(data, window.title, url);
}

/* Chrome 10 doesn't implement history.state. */
if("state" in history)
{
    /* Firefox 4 has a bug: it stores history states as JSON, so File objects
     * turn into simple Objects.  This happens even within the same browser session.
     * Detect if this is happening. */
    // XXX
//    var state = history.state;
//    history.replaceState(data, window.title);

}


/* Show the original image when the image is clicked and held. */
MainUI.prototype.change_mouse_pressed = function(down)
{
    this.mouse_pressed = down;
    this.update_display();
}

/* The mouse is pressed on the canvas.  Start listening for the mouseup,
 * and toggle the image to show the original. */
MainUI.prototype.canvas_mouse_down = function()
{
    window.addEventListener("pagehide", this.canvas_mouse_up, false);
    window.addEventListener("blur", this.canvas_mouse_up, false);
    this.change_mouse_pressed(true);
}

/* The mouse was released.  Stop listening, and toggle the image back to
 * the result. */
MainUI.prototype.canvas_mouse_up = function()
{
    window.removeEventListener("pagehide", this.canvas_mouse_up, false);
    window.removeEventListener("blur", this.canvas_mouse_up, false);
    this.change_mouse_pressed(false);
}

function init()
{
    var UI = new MainUI();
}
