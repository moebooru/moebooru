DebugWindow = function()
{
  this.shown = false;
  this.log_data = [];
  this.hooks = [];
  this.counter = 0;
  this.update = this.update.bind(this);

  this.hashchange_debug = this.hashchange_debug.bind(this);
  UrlHash.observe("debug", this.hashchange_debug);
  this.hashchange_debug();
}

DebugWindow.prototype.create_container = function()
{
  if(this.container)
    return;

  var div = document.createElement("DIV");
  div = $(div);
  div.className = "debug-box";
  div.setStyle({position: "fixed", top: "0px", height: "25%", backgroundColor: "#000", fontSize: "50%"});
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
  ++this.counter;
  this.log_data.push(this.counter + ": " + s);
  var lines = 10;
  if(this.log_data.length > lines)
    this.log_data = this.log_data.slice(1, lines+1);
  if(this.shown)
    this.update.defer();
}

DebugWindow.prototype.hashchange_debug = function()
{
  var debug = UrlHash.get("debug");
  if(debug == null)
    debug = "0";
  debug = (debug == "1");

  if(debug == this.shown)
    return;

  this.shown = debug;
  if(debug)
    this.create_container();
  else
    this.destroy_container();

  this.update();
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
    s += func() + "<br>";
  }
  s += this.log_data.join("<br>");

  if(s == this.shown_debug)
    return;

  this.shown_debug = s;
  this.container.update(s);
}

