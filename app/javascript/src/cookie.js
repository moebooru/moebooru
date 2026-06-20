import BaseCookies from 'js-cookie'

# welp
# Reference: https://github.com/js-cookie/js-cookie/blob/3f2b5e6884407c54b391483f39ddcd4c70f9243c/SERVER_SIDE.md
window.Cookies = BaseCookies
  .withConverter
    write: BaseCookies.converter.write
    read: (value) =>
      BaseCookies.converter.read value.replace(/\+/g, " ")
  .withAttributes
    path: Vars.prefix
    expires: 365

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
