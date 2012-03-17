"use strict";

var WebGLHelpers = {
    getShader: function(gl, id)
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
            shader = gl.createShader(gl.FRAGMENT_SHADER);
        else if (shaderScript.type == "x-shader/x-vertex")
            shader = gl.createShader(gl.VERTEX_SHADER);
        else
            throw "Unexpected type for shader: " + shaderScript.type;

        gl.shaderSource(shader, str);
        gl.compileShader(shader);

        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS))
        {
            alert(gl.getShaderInfoLog(shader));
            return null;
        }

        return shader;
    },

    initShaders: function(gl, vertex, fragment)
    {
        var vertexShader = WebGLHelpers.getShader(gl, vertex);
        var fragmentShader = WebGLHelpers.getShader(gl, fragment);

        var shaderProgram = gl.createProgram();
        gl.attachShader(shaderProgram, vertexShader);
        gl.attachShader(shaderProgram, fragmentShader);
        gl.linkProgram(shaderProgram);

        if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
            alert("Could not initialise shaders");
        }

        /* Store the uniform info, so we can access it quickly from setUniform. */
        var uniforms = gl.getProgramParameter(shaderProgram, gl.ACTIVE_UNIFORMS);
        shaderProgram.uniforms = {};
        for(var i = 0; i < uniforms; ++i)
        {
            var info = gl.getActiveUniform(shaderProgram, i);
            shaderProgram.uniforms[info.name] = info;
        }

        return shaderProgram;
    },

    setUniform: function(gl, program, name, value)
    {
        var index = gl.getUniformLocation(program, name);
        var info = program.uniforms[name];
        if(!info)
            return;

        if(typeof(value) == "number" || typeof(value) == "boolean")
            value = [value];

        if(info.type == gl.INT || info.type == gl.BOOL || info.type == gl.SAMPLER_2D || info.type == gl.SAMPLER_CUBE)
            gl.uniform1iv(index, value);
        else if(info.type == gl.INT_VEC2 || info.type == gl.BOOL_VEC2)
            gl.uniform2iv(index, value);
        else if(info.type == gl.INT_VEC3 || info.type == gl.BOOL_VEC3)
            gl.uniform3iv(index, value);
        else if(info.type == gl.INT_VEC4 || info.type == gl.BOOL_VEC4)
            gl.uniform4iv(index, value);
        else if(info.type == gl.FLOAT)
            gl.uniform1fv(index, value);
        else if(info.type == gl.FLOAT_VEC2)
            gl.uniform2fv(index, value);
        else if(info.type == gl.FLOAT_VEC3)
            gl.uniform3fv(index, value);
        else if(info.type == gl.FLOAT_VEC4)
            gl.uniform4fv(index, value);
        else if(info.type == gl.FLOAT_MAT2)
            gl.uniformMatrix2fv(index, false, value);
        else if(info.type == gl.FLOAT_MAT3)
            gl.uniformMatrix3fv(index, false, value);
        else if(info.type == gl.FLOAT_MAT4)
            gl.uniformMatrix4fv(index, false, value);
        else
            throw "Uniform " + name + " has unknown type " + info.type;
    }
};
