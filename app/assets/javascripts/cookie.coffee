# FIXME: I think the correct way would be replacing all calls to this
#        with jQuery.cookie.
(($) ->
  $.cookie.defaults['path'] = PREFIX
  $.cookie.defaults['expires'] = 365
  window.Cookie =
    put: (name, value, days) ->
      options = null
      if days
        options = expires: days
      $.cookie name, value, options
      return
    get: (name) ->
      # FIXME: compatibility reason. Should sweep this with !! check
      #        or something similar in relevant codes.
      $.cookie(name) or ''
    get_int: (name) ->
      parseInt $.cookie(name)
      return
    remove: (name) ->
      $.removeCookie name
      return
    unescape: (value) ->
      window.decodeURIComponent value.replace(/\+/g, ' ')
  return
) jQuery
