window.UrlHashHandler = ->
  @observers = new Hash

  @normalize = (h) ->

  @denormalize = (h) ->

  @deferred_sets = []
  @deferred_replace = false
  @current_hash = @parse(@get_raw_hash())
  @normalize @current_hash

  ### The last value received by the hashchange event: ###

  @last_hashchange = @current_hash.clone()
  @hashchange_event = @hashchange_event.bindAsEventListener(this)
  Element.observe window, 'hashchange', @hashchange_event
  return

UrlHashHandler::fire_observers = (old_hash, new_hash) ->
  all_keys = old_hash.keys()
  all_keys = all_keys.concat(new_hash.keys())
  all_keys = all_keys.uniq()
  changed_hash_keys = []
  all_keys.each ((key) ->
    old_value = old_hash.get(key)
    new_value = new_hash.get(key)
    if old_value != new_value
      changed_hash_keys.push key
    return
  ).bind(this)
  observers_to_call = []
  changed_hash_keys.each ((key) ->
    observers = @observers.get(key)
    if !observers?
      return
    observers_to_call = observers_to_call.concat(observers)
    return
  ).bind(this)
  universal_observers = @observers.get(null)
  if universal_observers?
    observers_to_call = observers_to_call.concat(universal_observers)
  observers_to_call.each (observer) ->
    observer changed_hash_keys, old_hash, new_hash
    return
  return

###
# Set handlers to normalize and denormalize the URL hash.
#
# Denormalizing a URL hash can convert the URL hash to something clearer for URLs.  Normalizing
# it reverses any denormalization, giving names to parameters.
#
# For example, if a normalized URL is
#
# http://www.example.com/app#show?id=1
#
# where the hash is {"": "show", id: "1"}, a denormalized URL may be
#
# http://www.example.com/app#show/1
#
# The denormalize callback will only be called with normalized input.  The normalize callback
# may receive any combination of normalized or denormalized input.
###

UrlHashHandler::set_normalize = (norm, denorm) ->
  @normalize = norm
  @denormalize = denorm
  @normalize @current_hash
  @set_all @current_hash.clone()
  return

UrlHashHandler::hashchange_event = (event) ->
  old_hash = @last_hashchange.clone()
  @normalize old_hash
  raw = @get_raw_hash()
  new_hash = @parse(raw)
  @normalize new_hash
  @current_hash = new_hash.clone()
  @last_hashchange = new_hash.clone()
  @fire_observers old_hash, new_hash
  return

###
# Parse a hash, returning a Hash.
#
# #a/b?c=d&e=f -> {"": 'a/b', c: 'd', e: 'f'}
###

UrlHashHandler::parse = (hash) ->
  if !hash?
    hash = ''
  if hash.substr(0, 1) == '#'
    hash = hash.substr(1)
  hash_path = hash.split('?', 1)[0]
  hash_query = hash.substr(hash_path.length + 1)
  hash_path = window.decodeURIComponent(hash_path)
  query_params = new Hash
  query_params.set '', hash_path
  if hash_query != ''
    hash_query_values = hash_query.split('&')
    i = 0
    while i < hash_query_values.length
      keyval = hash_query_values[i]

      ### a=b ###

      key = keyval.split('=', 1)[0]

      ### If the key is blank, eg. "#path?a=b&=d", then ignore the value.  It'll overwrite
      # the path, which is confusing and never what's wanted. 
      ###

      if key == ''
        ++i
        continue
      value = keyval.substr(key.length + 1)
      key = window.decodeURIComponent(key)
      value = window.decodeURIComponent(value)
      query_params.set key, value
      ++i
  query_params

UrlHashHandler::construct = (hash) ->
  s = '#'
  path = hash.get('')
  if path?

    ### For the path portion, we only need to escape the params separator ? and the escape
    # character % itself.  Don't use encodeURIComponent; it'll encode far more than necessary. 
    ###

    path = path.replace(/%/g, '%25').replace(/\?/g, '%3f')
    s += path
  params = []
  hash.each (k) ->
    key = k[0]
    value = k[1]
    if key == ''
      return
    if !value?
      return
    key = window.encodeURIComponent(key)
    value = window.encodeURIComponent(value)
    params.push key + '=' + value
    return
  if params.length != 0
    s += '?' + params.join('&')
  s

UrlHashHandler::get_raw_hash = ->

  ###
  # Firefox doesn't handle window.location.hash correctly; it decodes the contents,
  # where all other browsers give us the correct data.  http://stackoverflow.com/questions/1703552
  ###

  pre_hash_part = window.location.href.split('#', 1)[0]
  window.location.href.substr pre_hash_part.length

UrlHashHandler::set_raw_hash = (hash) ->
  query_params = @parse(hash)
  @set_all query_params
  return

UrlHashHandler::get = (key) ->
  @current_hash.get key

###
# Set keys in the URL hash.
#
# UrlHash.set({id: 50});
#
# If replace is true and the History API is available, replace the state instead
# of pushing it.
###

UrlHashHandler::set = (hash, replace) ->
  new_hash = @current_hash.merge(hash)
  @normalize new_hash
  @set_all new_hash, replace
  return

###
# Each call to UrlHash.set() will immediately set the new hash, which will create a new
# browser history slot.  This isn't always wanted.  When several changes are being made
# in response to a single action, all changes should be made simultaeously, so only a
# single history slot is created.  Making only a single call to set() is difficult when
# these changes are made by unrelated parts of code.
#
# Defer changes to the URL hash.  If several calls are made in quick succession, buffer
# the changes.  When a short timer expires, make all changes at once.  This will never
# happen before the current Javascript call completes, because timers will never interrupt
# running code.
#
# UrlHash.set() doesn't do this, because set() guarantees that the hashchange event will
# be fired and complete before the function returns.
#
# If replace is true and the History API is available, replace the state instead of pushing
# it.  If any set_deferred call consolidated into a single update has replace = false, the
# new state will be pushed.
###

UrlHashHandler::set_deferred = (hash, replace) ->
  @deferred_sets.push hash
  if replace
    @deferred_replace = true
  set = (->
    @deferred_set_timer = null
    new_hash = @current_hash
    @deferred_sets.each (m) ->
      new_hash = new_hash.merge(m)
      return
    @normalize new_hash
    @set_all new_hash, @deferred_replace
    @deferred_sets = []
    @hashchange_event null
    @deferred_replace = false
    return
  ).bind(this)
  if !@deferred_set_timer?
    @deferred_set_timer = set.defer()
  return

UrlHashHandler::set_all = (query_params, replace) ->
  query_params = query_params.clone()
  @normalize query_params
  @current_hash = query_params.clone()
  @denormalize query_params
  new_hash = @construct(query_params)
  if window.location.hash != new_hash

    ### If the History API is available, use it to support URL replacement.  FF4.0's pushState
    # is broken; don't use it. 
    ###

    if window.history and window.history.replaceState and window.history.pushState and !navigator.userAgent.match('Firefox/[45].')
      url = window.location.protocol + '//' + window.location.host + window.location.pathname + new_hash
      if replace
        window.history.replaceState {}, window.title, url
      else
        window.history.pushState {}, window.title, url
    else
      window.location.hash = new_hash

  ### Explicitly fire the hashchange event, so it's handled quickly even if the browser
  # doesn't support the event.  It's harmless if we get this event multiple times due
  # to the browser delivering it normally due to our change. 
  ###

  @hashchange_event null
  return

### Observe changes to the specified key.  If key is null, watch for all changes. ###

UrlHashHandler::observe = (key, func) ->
  observers = @observers.get(key)
  if !observers?
    observers = []
    @observers.set key, observers
  if observers.indexOf(func) != -1
    return
  observers.push func
  return

UrlHashHandler::stopObserving = (key, func) ->
  observers = @observers.get(key)
  if !observers?
    return
  observers = observers.without(func)
  @observers.set key, observers
  return

window.UrlHash = new UrlHashHandler
