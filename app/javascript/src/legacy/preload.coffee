_preload_image_pool = null

window.PreloadContainer = ->

  ### Initialize the pool the first time we make a container, since we may not
  # have ImgPoolHandler when the file is loaded. 
  ###

  if !_preload_image_pool?
    _preload_image_pool = new ImgPoolHandler
  @container = $(document.createElement('div'))
  @container.style.display = 'none'
  document.body.appendChild @container
  @active_preloads = 0
  @on_image_complete_event = @on_image_complete_event.bindAsEventListener(this)
  return

PreloadContainer::cancel_preload = (img) ->
  img.stopObserving()
  @container.removeChild img
  _preload_image_pool.release img
  if img.active
    --@active_preloads
  return

PreloadContainer::preload = (url) ->
  ++@active_preloads
  imgTag = _preload_image_pool.get()
  imgTag.observe 'load', @on_image_complete_event
  imgTag.observe 'error', @on_image_complete_event
  imgTag.src = url
  imgTag.active = true
  @container.appendChild imgTag
  imgTag

### Return an array of all preloads. ###

PreloadContainer::get_all = ->
  @container.childElements()

PreloadContainer::destroy = ->
  @get_all().each ((img) ->
    @cancel_preload img
    return
  ).bind(this)
  document.body.removeChild @container
  return

PreloadContainer::on_image_complete_event = (event) ->
  --@active_preloads
  event.target.active = false
  return

window.Preload =
  preload_list: []
  preload_container: null
  preload_raw_urls: []
  preload_started: false
  onload_event_initialized: false
  get_default_preload_container: ->
    if !@preload_container
      @preload_container = new PreloadContainer
    @preload_container
  init: ->
    if @onload_event_initialized
      return
    @onload_event_initialized = true
    Event.observe window, 'load', ->
      Preload.preload_started = true
      Preload.start_preload()
      return
    return
  preload: (url) ->
    container = @get_default_preload_container()
    Preload.init()
    Preload.preload_list.push [
      url
      container
    ]
    Preload.start_preload()
    return
  preload_raw: (url) ->
    Preload.init()
    Preload.preload_raw_urls.push url
    Preload.start_preload()
    return
  create_raw_preload: (url) ->
    new (Ajax.Request)(url,
      method: 'get'
      evalJSON: false
      evalJS: false
      parameters: null)
  start_preload: ->
    if !Preload.preload_started
      return
    i = undefined
    i = 0
    while i < Preload.preload_list.length
      preload = Preload.preload_list[i]
      container = preload[1]
      container.preload preload[0]
      ++i
    Preload.preload_list.length = []
    i = 0
    while i < Preload.preload_raw_urls.length
      url = Preload.preload_raw_urls[i]
      Preload.create_raw_preload url
      ++i
    Preload.preload_raw_urls = []
    return
