"use strict";

var HistogramHelpers = {
    /* Return a Uint8Array containing the RGBA pixel data for the given image.  If
     * the pixel data can't be loaded due to same-origin restrictions, return null. */
    getImageDataFromImg: function(img)
    {
        var canvas = document.createElement("canvas");
        canvas.width = img.width;
        canvas.height = img.height;

        var ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, img.width, img.height);
        try {
            var image_data = ctx.getImageData(0, 0, img.width, img.height);
        } catch(e) {
            if(e instanceof DOMException)
            {
                console.log("Can't load pixel data for image from different origin");
                return null;
            }
            throw e;
        }
        return new Uint8Array(image_data.data);
    },

    /* Return an un-normalized histogram for the given channel. */
    make_histogram: function(input, pixels, channel)
    {
        pixels *= 4;

        var result = new Float32Array(256);
        for(var i = 0; i < pixels; i += 4)
        {
            var color = input[i+channel];
            result[color] += 1;
        }

        return result;
    },

    /* Return a 256x3 array of raw histogram sums for the given image.
     * The image must be same-origin. */
    create_raw_histograms: function(img)
    {
        var array = HistogramHelpers.getImageDataFromImg(img);
        if(array == null)
            return null;

        var red = HistogramHelpers.make_histogram(array, img.width*img.height, 0);
        var green = HistogramHelpers.make_histogram(array, img.width*img.height, 1);
        var blue = HistogramHelpers.make_histogram(array, img.width*img.height, 2);
        return [red, green, blue];
    },
    
    /* Given raw [R,G,B] histogram data, return an array of normalized RGB, R, G and B
     * histograms. */
    create_histograms: function(histograms)
    {
        var red = histograms[0], green = histograms[1], blue = histograms[2];

        /* Combine the three histograms to make the RGB histogram. */
        var rgb = new Float32Array(256);
        for(var i = 0; i < 256; ++i)
            rgb[i] += red[i] + green[i] + blue[i];

        var histograms = [rgb, red, green, blue];

        for(var channel = 0; channel < 4; ++channel)
        {
            var histogram = histograms[channel];

            for(var i = 0; i < 256; ++i)
                histogram[i] = Math.pow(histogram[i], 0.4);

            /* Normalize each histogram to [0,256). */
            var max = 0;
            for(var i = 0; i < 256; ++i)
                max = Math.max(max, histogram[i]);
//            max /= 256.0;
            for(var i = 0; i < 256; ++i)
                histogram[i] = histogram[i] / max;
        }

        return histograms;
    },

    convertTo8bit: function(array)
    {
        var ret = new Uint8Array(array.length);
        for(var i = 0; i < array.length; ++i)
        {
            var val = Math.floor(array[i] * 256);

            /* Make sure an exact value of 1.0 doesn't overflow. */
            val = Math.min(val, 255);
            ret[i] = val;
        }
        return ret;
    }
};




var Histogram = function(canvas)
{
    this.canvas = canvas;

    this.gl = null;
    try {
        this.gl = this.canvas.getContext("experimental-webgl", { depth: false, alpha: true, premultipliedAlpha: false });
    } catch(e) { };

    if (!this.gl)
        throw "Couldn't initialize WebGL";

    console.log("Extensions: " + this.gl.getSupportedExtensions());

    // XXX
    // var ext = this.gl.getExtension("OES_texture_float");
    // console.log(ext);

    /* Debugging: Firefox has returned RGB565 textures, which isn't legal. */
    var bits_red = this.gl.getParameter(this.gl.RED_BITS);
    var bits_green = this.gl.getParameter(this.gl.GREEN_BITS);
    var bits_blue = this.gl.getParameter(this.gl.BLUE_BITS);
    if(bits_red < 8 || bits_green < 8 || bits_blue < 8)
        console.warn("Expected RGB8 or better, got: " + bits_red + " " + bits_green +  " " + bits_blue);

    this.shaderRenderProgram = WebGLHelpers.initShaders(this.gl, "histogram-render-vs", "histogram-render-fs");
    this.initBuffers();

    this.gl.clearColor(0.0, 0.0, 0.0, 1.0);
}




Histogram.prototype.initBuffers = function()
{
    this.squareVertexPositionBuffer = this.gl.createBuffer();
    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.squareVertexPositionBuffer);
    var vertices = [
	 0.0,  0.0,
	 1.0,  0.0,
	 0.0,  1.0,
	 1.0,  1.0,
    ];
    this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(vertices), this.gl.STATIC_DRAW);
}

Histogram.prototype.load_ajax_histogram = function(url)
{
    if(this.histogram_request)
    {
        this.histogram_request.abort();
        this.histogram_request = null;
    }
    if(url == null)
        return;

    console.log("Load histogram for " + url);
    var xhr = new XMLHttpRequest();
    this.histogram_request = xhr;
    // xhr.open("GET", "http://10.0.0.1:8998/histogram?url=" + encodeURIComponent(url), true);
    xhr.open("GET", "/histogram?url=" + encodeURIComponent(url), true);

    xhr.onload = function(resp)
    {
        this.histogram_request = null;

        try {
            var results = JSON.parse(xhr.responseText);
        } catch(e) {
            return;
        }

        if(results.error)
        {
            console.warn("Loading histogram for " + url + ": " + results.error);
            return;
        }
        this.load_histogram_data(results.data);
    }.bind(this);

    xhr.onerror = function(resp)
    {
        this.histogram_request = null;

        console.log("error", xhr.responseText);
    }.bind(this);
    xhr.send();
}

/* histogram is a 256x3 array of raw histogram data for each channel. */
Histogram.prototype.load_histogram_data = function(raw_histograms)
{
    /* Create the RGB channel and normalize the results. */
    var histograms = HistogramHelpers.create_histograms(raw_histograms);

    this.image_loaded = true;

    if(!this.gl.getExtension("OES_texture_float")||1)
    {
        console.log("Using 8-bit histogram");

        /* Convert the histograms to Uint8Array. */
        for(var channel = 0; channel < 4; ++channel)
            histograms[channel] = HistogramHelpers.convertTo8bit(histograms[channel]);
    }
    else
        console.log("Using OES_texture_float for histogram");

    this.histogram_textures = [];
    for(var channel = 0; channel < 4; ++channel)
    {
        var histogram_texture = this.gl.createTexture();
        this.histogram_textures.push(histogram_texture);
        this.gl.bindTexture(this.gl.TEXTURE_2D, histogram_texture);

        var type = this.gl.UNSIGNED_BYTE;
        if(histograms[channel] instanceof Float32Array)
            type = this.gl.FLOAT;
        this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.LUMINANCE,
            256, 1,
            0, this.gl.LUMINANCE, type, histograms[channel]);

        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.NEAREST);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.NEAREST);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_S, this.gl.CLAMP_TO_EDGE);
        this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_T, this.gl.CLAMP_TO_EDGE);
        
    }

    this.draw();
}

/* Load the source texture from the given image.  If img is null, unload
 * the texture. */
Histogram.prototype.load_texture = function(img)
{
    if(img && this.image_loaded_url == img.src)
        return;
    this.image_loaded_url = img? img.src:null;

    /* We're changing images.  Cancel any AJAX request in flight. */
    this.image_loaded = false;
    this.load_ajax_histogram(null);

    if(!img)
        return;

    /* Try to load a histogram directly.  This will only work for same-origin images. */
    var raw_histograms = HistogramHelpers.create_raw_histograms(img);
    if(raw_histograms != null)
    {
        this.load_histogram_data(raw_histograms);
        return;
    }

    /* We couldn't load the image directly.  Try to have the server do it for us.
     * Draw the display, so we clear anything there while the request is running;
     * we don't do this when loading locally to reduce flicker. */
    this.draw();
    this.load_ajax_histogram(img.src);
}

Histogram.prototype.set_channel = function(channel)
{
    this.displayed_channel = channel;
}

Histogram.prototype.draw = function()
{
    var channel = this.displayed_channel;

    this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    this.gl.clearColor(1,1,1,1);
    this.gl.clear(this.gl.COLOR_BUFFER_BIT);

    if(!this.image_loaded)
        return;

    this.gl.useProgram(this.shaderRenderProgram);

    var pMatrix = mat4.create();
    mat4.ortho(0, 1, 1, 0, -1, 1, pMatrix);

    WebGLHelpers.setUniform(this.gl, this.shaderRenderProgram, "uPMatrix", pMatrix);

    var rectangleBuffer = this.gl.createBuffer();
    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, rectangleBuffer);
    var vertices = [
	 0.0,  0.0,
	 1.0,  0.0,
	 0.0,  1.0,
	 1.0,  1.0,
    ];
    this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(vertices), this.gl.STATIC_DRAW);
    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, rectangleBuffer);
    var vertexPositionAttribute = this.gl.getAttribLocation(this.shaderRenderProgram, "aVertexPosition");
    this.gl.enableVertexAttribArray(vertexPositionAttribute);
    this.gl.vertexAttribPointer(vertexPositionAttribute, 2, this.gl.FLOAT, false, 0, 0);

    var colors = [
        [0.85, 0.85, 0.85],
        [1.0, 0.8, 0.7],
        [0.8, 1.0, 0.7],
        [0.85, 0.85, 1.0]
    ];
    WebGLHelpers.setUniform(this.gl, this.shaderRenderProgram, "uColor", colors[channel]);

    this.gl.activeTexture(this.gl.TEXTURE0);
    this.gl.bindTexture(this.gl.TEXTURE_2D, this.histogram_textures[channel]);
    WebGLHelpers.setUniform(this.gl, this.shaderRenderProgram, "uSampler", 0);

    this.gl.drawArrays(this.gl.TRIANGLE_STRIP, 0, 4);

    this.gl.activeTexture(this.gl.TEXTURE0);
    this.gl.bindTexture(this.gl.TEXTURE_2D, null);

    var error = this.gl.getError();
    if(error)
        console.warn("WebGL error: " + error);
}

