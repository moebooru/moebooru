"use strict";

/*
 * Todo:
 * contextLostHandler, contextRestoredHandler: browsers need a way to trigger
 * this, it's currently untestable
 *
 * Better error handling.
 */
var Renderer = function(canvas)
{
    this.canvas = canvas;

    this.gl = null;
    try {
        this.gl = this.canvas.getContext("experimental-webgl", { depth: false });
    } catch(e) { };

    if (!this.gl)
        throw "Couldn't initialize WebGL";

    this.initShaders();
    this.initBuffers();

    this.gl.clearColor(0.0, 0.0, 0.0, 1.0);

    this.texture = this.initTexture();
    this.lut_texture = this.lutTextureCreate();

    /* Create a default no-op LUT. */
    var lut = [];
    for(var channel = 0; channel < 3; ++channel)
        for(var i = 0; i < 256; ++i)
            lut.push(i);
    this.lutTextureSet(new Uint8Array(lut));
}

Renderer.prototype.getShader = function(id)
{
    var shaderScript = document.getElementById(id);
    if(!shaderScript)
	return null;

    var str = "";
    var k = shaderScript.firstChild;
    while (k) {
	if (k.nodeType == 3)
	    str += k.textContent;
	k = k.nextSibling;
    }

    var shader;
    if (shaderScript.type == "x-shader/x-fragment")
	shader = this.gl.createShader(this.gl.FRAGMENT_SHADER);
    else if (shaderScript.type == "x-shader/x-vertex")
	shader = this.gl.createShader(this.gl.VERTEX_SHADER);
    else
        throw "Unexpected type for shader: " + shaderScript.type;

    this.gl.shaderSource(shader, str);
    this.gl.compileShader(shader);

    if (!this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS))
    {
	alert(this.gl.getShaderInfoLog(shader));
	return null;
    }

    return shader;
}


Renderer.prototype.initShaders = function()
{
    var fragmentShader = this.getShader("shader-fs");
    var vertexShader = this.getShader("shader-vs");

    this.shaderProgram = this.gl.createProgram();
    this.gl.attachShader(this.shaderProgram, vertexShader);
    this.gl.attachShader(this.shaderProgram, fragmentShader);
    this.gl.linkProgram(this.shaderProgram);

    if (!this.gl.getProgramParameter(this.shaderProgram, this.gl.LINK_STATUS)) {
	alert("Could not initialise shaders");
    }

    this.gl.useProgram(this.shaderProgram);

    this.shaderProgram.vertexPositionAttribute = this.gl.getAttribLocation(this.shaderProgram, "aVertexPosition");
    this.gl.enableVertexAttribArray(this.shaderProgram.vertexPositionAttribute);

    this.shaderProgram.textureCoordAttribute = this.gl.getAttribLocation(this.shaderProgram, "aTextureCoord");
    this.gl.enableVertexAttribArray(this.shaderProgram.textureCoordAttribute);

    this.shaderProgram.pMatrixUniform = this.gl.getUniformLocation(this.shaderProgram, "uPMatrix");
    this.shaderProgram.imageUniform = this.gl.getUniformLocation(this.shaderProgram, "uSampler");
    this.shaderProgram.lutUniform = this.gl.getUniformLocation(this.shaderProgram, "uLUTSampler");
}

Renderer.prototype.initBuffers = function()
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

    this.squareVertexTextureCoordBuffer = this.gl.createBuffer();
    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.squareVertexTextureCoordBuffer);
    var textureCoords = [
      0.0, 0.0,
      1.0, 0.0,
      0.0, 1.0,
      1.0, 1.0,
    ];
    this.gl.bufferData(this.gl.ARRAY_BUFFER, new Float32Array(textureCoords), this.gl.STATIC_DRAW);
}


Renderer.prototype.draw = function()
{
    this.gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    this.gl.clear(this.gl.COLOR_BUFFER_BIT);

    var pMatrix = mat4.create();
    mat4.ortho(0, 1, 1, 0, -1, 1, pMatrix);

    this.gl.activeTexture(this.gl.TEXTURE0);
    this.gl.bindTexture(this.gl.TEXTURE_2D, this.texture);
    this.gl.uniform1i(this.shaderProgram.imageUniform, 0);

    this.gl.activeTexture(this.gl.TEXTURE1);
    this.gl.bindTexture(this.gl.TEXTURE_2D, this.lut_texture);
    this.gl.uniform1i(this.shaderProgram.lutUniform, 1);

    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.squareVertexTextureCoordBuffer);
    this.gl.vertexAttribPointer(this.shaderProgram.textureCoordAttribute, 2, this.gl.FLOAT, false, 0, 0);

    this.gl.bindBuffer(this.gl.ARRAY_BUFFER, this.squareVertexPositionBuffer);
    this.gl.vertexAttribPointer(this.shaderProgram.vertexPositionAttribute, 2, this.gl.FLOAT, false, 0, 0);

    this.gl.uniformMatrix4fv(this.shaderProgram.pMatrixUniform, false, pMatrix);

    this.gl.drawArrays(this.gl.TRIANGLE_STRIP, 0, 4);

    this.gl.activeTexture(this.gl.TEXTURE0);
    this.gl.bindTexture(this.gl.TEXTURE_2D, null);
    this.gl.activeTexture(this.gl.TEXTURE1);
    this.gl.bindTexture(this.gl.TEXTURE_2D, null);


}

Renderer.prototype.lutTextureCreate = function()
{
    var texture = this.gl.createTexture();
    this.gl.bindTexture(this.gl.TEXTURE_2D, texture);

    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.NEAREST);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.NEAREST);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_S, this.gl.CLAMP_TO_EDGE);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_T, this.gl.CLAMP_TO_EDGE);
    
    this.gl.bindTexture(this.gl.TEXTURE_2D, null);

    return texture;
}

Renderer.prototype.lutTextureSet = function(lut)
{
    /* The LUT has one row for each LUT channel. */
    var lut_channels = 3;
    var lut_colors = 256;

    if(lut.length != lut_channels*lut_colors)
        throw "LUT should have a length of " + (lut_channels*lut_colors) + "; received " + lut.length;

    this.gl.bindTexture(this.gl.TEXTURE_2D, this.lut_texture);

    this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.LUMINANCE, 256, lut.length / 256, 0,
        this.gl.LUMINANCE, this.gl.UNSIGNED_BYTE, lut);

    this.gl.bindTexture(this.gl.TEXTURE_2D, null);
}

Renderer.prototype.initTexture = function()
{
    var texture = this.gl.createTexture();
    this.gl.bindTexture(this.gl.TEXTURE_2D, texture);

    /* For NPOT support, filtering must be NEAREST or LINEAR, and the clamp mode must
     * be CLAMP_TO_EDGE. */
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MAG_FILTER, this.gl.NEAREST);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_MIN_FILTER, this.gl.NEAREST);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_S, this.gl.CLAMP_TO_EDGE);
    this.gl.texParameteri(this.gl.TEXTURE_2D, this.gl.TEXTURE_WRAP_T, this.gl.CLAMP_TO_EDGE);

    this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, 10, 10, 0,
        this.gl.RGBA, this.gl.UNSIGNED_BYTE, null);

    this.gl.bindTexture(this.gl.TEXTURE_2D, null);
    return texture;
}

/* Load the source texture from the given image.  If img is null, unload
 * the texture. */
Renderer.prototype.loadTexture = function(img)
{
    this.gl.bindTexture(this.gl.TEXTURE_2D, this.texture);
    if(img)
        this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, this.gl.RGBA, this.gl.UNSIGNED_BYTE, img);
    else
        this.gl.texImage2D(this.gl.TEXTURE_2D, 0, this.gl.RGBA, 10, 10, 0,
            this.gl.RGBA, this.gl.UNSIGNED_BYTE, null);
    this.gl.bindTexture(this.gl.TEXTURE_2D, null);

    if(img)
    {
        this.canvas.width = img.width;
        this.canvas.height = img.height;
    }
}

