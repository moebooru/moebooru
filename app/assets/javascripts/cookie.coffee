Cookies.defaults['path'] = PREFIX
Cookies.defaults['expires'] = 365

window.Cookie =
  put: (name, value, days) ->
    options = expires: days if days
    Cookies name, value

  get: (name) ->
    # FIXME: compatibility reason. Should sweep this with !! check
    #        or something similar in relevant codes.
    Cookies(name) || ''

  get_int: (name) ->
    parseInt Cookies(name)

  remove: (name) ->
    Cookies.remove name

  unescape: (value) ->
    window.decodeURIComponent value.replace(/\+/g, ' ')
