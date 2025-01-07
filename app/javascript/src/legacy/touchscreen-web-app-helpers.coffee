import EmulateDoubleClick from 'src/classes/emulate_double_click'
import ResponsiveSingleClick from 'src/classes/responsive_single_click'
import { maintainUrlHash } from 'src/utils/maintain_url_hash'
###
# This file implements several helpers for fixing up full-page web apps on touchscreen
# browsers:
#
# EmulateDoubleClick
# ResponsiveSingleClick
#
# Most of these are annoying hacks to work around the fact that WebKit on browsers was
# designed with displaying scrolling webpages in mind, apparently without consideration
# for full-screen applications: pages that should fill the screen at all times.  Most
# of the browser mobile hacks no longer make sense: separate display viewports, touch
# dragging, double-click zooming and their associated side-effects.
###

window.InitializeFullScreenBrowserHandlers = ->
  # These handlers deal with heavily browser-specific issues.  Only install them
  # on browsers that have been tested to need them. 
  if navigator.userAgent.indexOf('Android') != -1 and navigator.userAgent.indexOf('WebKit') != -1
    new ResponsiveSingleClick
    new EmulateDoubleClick
  else if (navigator.userAgent.indexOf('iPhone') != -1 or navigator.userAgent.indexOf('iPad') != -1 or navigator.userAgent.indexOf('iPod') != -1) and navigator.userAgent.indexOf('WebKit') != -1
    new ResponsiveSingleClick
    new EmulateDoubleClick

    ### In web app mode only: ###

    if window.navigator.standalone
      maintainUrlHash()
  return
