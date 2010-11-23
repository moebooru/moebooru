DebugWindow = function()
{
  this.shown = false;
  this.log_data = [];
  this.hooks = [];

  this.set_debug = this.set_debug.bind(this);

  this.hashchange_debug = this.hashchange_debug.bind(this);
  UrlHash.observe("debug", this.hashchange_debug);
  this.hashchange_debug();
}

DebugWindow.prototype.create_container = function()
{
  if(this.container)
    return;

  var div = document.createElement("DIV");
  div.className = "debug-box";
  div.setStyle({position: "fixed", bottom: "100px", maxHeight: "50%", backgroundColor: "#000"});
  document.body.appendChild(div);
  this.container = div;

  this.shown_debug = "";
}

DebugWindow.prototype.destroy_container = function()
{
  if(!this.container)
    return;
  document.body.removeChild(this.container);
  this.container = null;
}

DebugWindow.prototype.log = function(s)
{
  this.log_data.push(s);
  var lines = 30;
  if(this.log_data.length > lines)
    this.log_data = this.log_data.slice(1, lines+1);
  this.update();
}

DebugWindow.prototype.hashchange_debug = function()
{
  var debug = UrlHash.get("debug") == "1";
  if(debug == this.shown)
    return;

  this.shown = debug;
  if(debug)
    this.create_container();
  else
    this.destroy_container();

  this.update();

  if(!this.debug_timer)
    this.set_debug();
}

DebugWindow.prototype.add_hook = function(func)
{
  this.hooks.push(func);
}

DebugWindow.prototype.update = function()
{
  if(!this.container)
    return;

  var s = "";
  for(var i = 0; i < this.hooks.length; ++i)
  {
    var func = this.hooks[i];
    s += func();
  }
  s += " -- " + this.log_data.join("<br>");

  if(s == this.shown_debug)
    return;

  this.shown_debug = s;
  this.container.update(s);
}

DebugWindow.prototype.set_debug = function()
{
  this.debug_timer = null;
  if(!this.shown)
    return;

  this.debug_timer = window.setTimeout(this.set_debug, 100);
  this.update();
}

