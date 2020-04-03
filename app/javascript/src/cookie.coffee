# welp
# Reference: https://github.com/js-cookie/js-cookie/blob/3f2b5e6884407c54b391483f39ddcd4c70f9243c/SERVER_SIDE.md
window.Cookies = Cookies.withConverter
  write: (value) =>
    encodeURIComponent value
      .replace /%(23|24|26|3A|3C|3E|3D|2F|3F|40|5B|5D|5E|60|7B|7D|7C)/g, decodeURIComponent

  read: (value) =>
    value
      .replace /\+/g, " "
      .replace /(%[0-9A-Z]{2})+/g, decodeURIComponent


Cookies.defaults.path = PREFIX
Cookies.defaults.expires = 365

window.Cookie =
  put: (name, value, days) ->
    options = expires: days if days
    Cookies.set name, value, options

  get: (name) ->
    # FIXME: compatibility reason. Should sweep this with !! check
    #        or something similar in relevant codes.
    Cookies.get(name) || ''

  get_int: (name) ->
    parseInt Cookies.get(name), 10

  remove: (name) ->
    Cookies.remove name

  unescape: (value) ->
    window.decodeURIComponent value.replace(/\+/g, ' ')
