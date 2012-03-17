"use strict";

var InterpolationData = function(points)
{
    this.points = points;
    this.getSecondDerivative(points);
}

InterpolationData.prototype.getX = function(i, t)
{
    var p0 = this.points[i];
    var p1 = this.points[i+1];
    return p0.x + t*(p1.x - p0.x);
}

InterpolationData.prototype.getY = function(i, t)
{
    var p0 = this.points[i];
    var p1 = this.points[i+1];
    var u = 1-t;
    var h = p1.x - p0.x;
    return (u * p0.y + t * p1.y) + (h*h / 6) * ((((u*u*u) - u) * p0.d) + (((t*t*t) - t) * p1.d));
}

// Fill in the second derivative for each point in points.
InterpolationData.prototype.getSecondDerivative = function(points)
{
    var n = points.length;

    // build the tridiagonal system
    // (assume 0 boundary conditions: y2[0]=y2[-1]=0)
    var matrix = [];
    for(var i = 0; i < n; ++i)
        matrix.push([0,0,0]);
    matrix[0][1] = 1;
    matrix[n-1][1] = 1;

    points[0].d = 0;
    for(var i = 1; i < n-1; ++i)
    {
        matrix[i][0] = (points[i].x-points[i-1].x)/6;
        matrix[i][1] = (points[i+1].x-points[i-1].x)/3;
        matrix[i][2] = (points[i+1].x-points[i].x)/6;
        var val = (points[i+1].y-points[i].y)/(points[i+1].x-points[i].x) - (points[i].y-points[i-1].y)/(points[i].x-points[i-1].x);
        points[i].d = val;
    }
    points[n-1].d = 0;

    // solving pass1 (up->down)
    for(var i = 1; i < n; ++i)
    {
        var k = matrix[i][0] / matrix[i-1][1];
        matrix[i][1] -= k * matrix[i-1][2];
        matrix[i][0] = 0;
        points[i].d -= k * points[i-1].d;
    }

    // solving pass2 (down->up)
    for(var i = n-2; i >= 0; --i)
    {
        var k = matrix[i][2] / matrix[i+1][1];
        matrix[i][1] -= k*matrix[i+1][0];
        matrix[i][2] = 0;
        points[i].d -= k*points[i+1].d;
    }

    // return second derivative value for each point
    for(var i = 0; i < n; ++i)
        points[i].d /= matrix[i][1];
}


InterpolationData.prototype.get = function(i, t)
{
    return this.getX(i, t), this.getY(i, t);
}

// def check(): make sure X values are monotonic

InterpolationData.prototype.getIdxForX = function(x, startAtIdx)
{
    if(!startAtIdx)
        startAtIdx = 0;
    // Find the pair of points that this X value lies between, and return its first index.
    if(x <= this.points[startAtIdx].x)
        return 0;
    for(var i = startAtIdx; i < this.points.length - 1; ++i)
    {
        if(x < this.points[i].x || x > this.points[i+1].x)
            continue;
        return i;
    }

    // Return the last pair.
    return this.points.length-2;
}

InterpolationData.prototype.getXPoint = function(x, i)
{
    // Return t for a given X.
    var x0 = this.points[i].x;
    var x1 = this.points[i+1].x;
    return (x - x0) / (x1 - x0);
}

InterpolationData.prototype.getYfromX = function(x)
{
    var i = this.getIdxForX(x, 0);
    var t = this.getXPoint(x, i);
    var y = this.getY(i, t);
    y = Math.max(y, 0);
    y = Math.min(y, 255);
    return y;
}


/* Points can be disabled during dragging. */
function Point(x, y) { this.x = x; this.y = y; this.d = 0; this.disabled = false; }

var Interpolation = function(empty)
{
    this.points = [];

    if(!empty)
    {
        /* Create the default points.  We must always have a starting point and an
         * ending point, which can't be deleted.  If empty is true, then the caller
         * is going to populate values manually. */
        this.set_point(0, 0);
        this.set_point(255, 255);
    }
}

/* Find the point at the specified X coordinate.  If it doesn't exist,
 * return the position where a new point at that coordinate should be
 * interted. */
Interpolation.prototype.find_point = function(x)
{
    for(var i = 0; i < this.points.length; ++i)
    {
        if(this.points[i].x >= x)
            return i;
    }
    return this.points.length;
}

/* Insert or modify the point at the specified X coordinate. */
Interpolation.prototype.set_point = function(x, y)
{
    var idx = this.find_point(x);
    if(idx >= this.points.length || this.points[idx].x != x)
    {
        var point = new Point(x, y);
        this.points.splice(idx, 0, point);
        return [idx, true];
    }
    else
    {
        this.points[idx].y = y;
        return [idx, false];
    }
}

/* Return a unity LUT. */
Interpolation.prototype.get_default_lut = function()
{
    var lut = [];
    for(var x = 0; x < 256; ++x)
        lut.push(x);
    return lut;
}

Interpolation.prototype.getInterpolationData = function()
{
    /* Ignore disabled points. */
    var filtered_points = this.points.filter(function(point) { return !point.disabled; });
    if(filtered_points.length < 2)
        throw "Too few enabled points to getInterpolationData (" + filtered_points.length + ")";
    return new InterpolationData(filtered_points);
}

Interpolation.prototype.get_lut = function(show_clipping)
{
    var interp = this.getInterpolationData();
    var lut = [];
    var i = 0;
    for(var x = 0; x < 256; ++x)
    {
        i = interp.getIdxForX(x, i);
        var t = interp.getXPoint(x, i);

        /* If t is outside of [0,1], then it's a clipped value, outside any points.
         * If show_clipping is enabled, mark all of these values with the sentinel
         * 1000; otherwise just clamp the value. */
        if(show_clipping && (t < 0 || t > 1))
        {
            lut.push(1000);
            continue;
        }

        t = Math.min(Math.max(t, 0), 1);
        var y = interp.getY(i, t);

        /* If the result is outside of [0,255], it's also clipped. */
        if(show_clipping && (y < 0 || y > 255))
        {
            lut.push(1000);
            continue;
        }

        /* Clamp the results to [0,255]. */
        y = Math.max(y, 0);
        y = Math.min(y, 255);
        lut.push(y);
    }
    if(show_clipping)
    {
        lut[0] = lut[255] = 255;
        lut[1000] = 1000;
    }

    return lut;
}

Interpolation.prototype.is_unity = function()
{
    for(var i = 0; i < this.points.length; ++i)
    {
        var point = this.points[i];
        if(point.x != point.y)
            return false;
    }
    return true;
}

