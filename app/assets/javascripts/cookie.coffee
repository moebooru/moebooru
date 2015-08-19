Cookies.defaults['path'] = PREFIX
Cookies.defaults['expires'] = 365

# welp
# Reference: https://github.com/js-cookie/js-cookie/issues/70
oldCookies = Cookies.noConflict()
window.Cookies = oldCookies.withConverter (value) ->
  decodeURIComponent value.replace(/\+/g, ' ')

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
