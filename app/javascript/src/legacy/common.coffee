Object.extend Element.Methods,
  showBase: Element.show
  show: (element, visible) ->
    if visible or !visible?
      $(element).showBase()
    else
      $(element).hide()
Element.addMethods()

Prototype.Browser.AndroidWebKit = navigator.userAgent.indexOf('Android') != -1 and navigator.userAgent.indexOf('WebKit') != -1

# Some UI simply doesn't make sense on a touchscreen, and may need to be disabled or changed.
# It'd be nice if this could be done generically, but this is the best available so far...
Prototype.BrowserFeatures.Touchscreen =
  # iOS WebKit has window.Touch, a constructor for Touch events.
  window.Touch? ||
  # Mozilla/5.0 (Linux; U; Android 2.2; en-us; sdk Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1
  navigator.userAgent.indexOf('Mobile Safari/') != -1 ||
  # Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_2 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Mobile/8C134
  navigator.userAgent.indexOf('Mobile/') != -1
