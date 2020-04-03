window.DebugWindow = ->
  @shown = false
  @log_data = []
  @hooks = []
  @counter = 0
  @update = @update.bind(this)
  @hashchange_debug = @hashchange_debug.bind(this)
  UrlHash.observe 'debug', @hashchange_debug
  @hashchange_debug()
  @log '*** Started'
  return

DebugWindow::create_container = ->
  if @container
    return
  div = document.createElement('DIV')
  div = $(div)
  div.className = 'debug-box'
  div.setStyle
    position: 'fixed'
    top: '0px'
    right: '0px'
    height: '25%'
    backgroundColor: '#000'
    fontSize: '100%'
  document.body.appendChild div
  @container = div
  @shown_debug = ''
  return

DebugWindow::destroy_container = ->
  if !@container
    return
  document.body.removeChild @container
  @container = null
  return

DebugWindow::log = (s) ->

  ###
  # Output to the console log, if any.
  #
  # In FF4, this goes to the Web Console.  (It doesn't go to the error console; it should.)
  # On Android, this goes to logcat.
  # On iPhone, this goes to the intrusive Debug Console if it's turned on (no way to redirect
  # it outside of the phone).
  ###

  if window.console and window.console.log
    console.log s
  ++@counter
  @log_data.push @counter + ': ' + s
  lines = 10
  if @log_data.length > lines
    @log_data = @log_data.slice(1, lines + 1)
  if @shown
    @update.defer()
  return

DebugWindow::hashchange_debug = ->
  debug = UrlHash.get('debug')
  if debug == null or debug == undefined
    debug = '0'
  debug = debug == '1'
  if debug == @shown
    return
  @shown = debug
  if debug
    @create_container()
  else
    @destroy_container()
  @update()
  return

DebugWindow::add_hook = (func) ->
  @hooks.push func
  return

DebugWindow::update = ->
  if !@container
    return
  s = ''
  i = 0
  while i < @hooks.length
    func = @hooks[i]
    s += func() + '<br>'
    ++i
  s += @log_data.join('<br>')
  if s == @shown_debug
    return
  @shown_debug = s
  @container.update s
  return

###
# Return a function, debug(), which logs to a debug window.  The actual debug
# handler is an attribute of the function.
#
# var debug = NewDebug();
# debug("text");
# debug.handler.add_hook();
###

window.NewDebug = ->
  debug_handler = new DebugWindow
  debug = debug_handler.log.bind(debug_handler)
  debug.handler = debug_handler
  debug
