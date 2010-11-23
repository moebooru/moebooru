DebugWindow = function(container)
{
  this.container = container;
  this.shown = false;
  this.log_data = " ";
  this.hooks = [];

  this.set_debug = this.set_debug.bind(this);

  this.hashchange_debug = this.hashchange_debug.bind(this);
  UrlHash.observe("debug", this.hashchange_debug);
  this.hashchange_debug();
}

DebugWindow.prototype.log = function(s)
{
  this.log_data += "<br>" + s;
  var max_length = 5000;
  if(this.log_data.length > max_length)
    this.log_data = this.log_data.substr(this.log_data.length-max_length, max_length);
  this.update();
}

DebugWindow.prototype.hashchange_debug = function()
{
  var debug = UrlHash.get("debug") == "1";
  if(debug == this.shown)
    return;

  this.shown = debug;
  this.container.show(this.shown);

  if(this.shown)
    this.set_debug();
}

DebugWindow.prototype.add_hook = function(func)
{
  this.hooks.push(func);
}

DebugWindow.prototype.update = function()
{
  var s = "";
  for(var i = 0; i < this.hooks.length; ++i)
  {
    var func = this.hooks[i];
    s += func();
  }
  s += " -- " + this.log_data;

  if(s == this.shown_debug)
    return;

  this.shown_debug = s;
  this.container.update(s);
}

DebugWindow.prototype.set_debug = function()
{
  this.debug_timer = window.setTimeout(this.set_debug, 100);
  this.update();
}

