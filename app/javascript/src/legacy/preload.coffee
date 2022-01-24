import PreloadContainer from 'src/classes/preload_container'

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
