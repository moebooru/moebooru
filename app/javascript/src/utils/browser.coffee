isWebkitCache = null

export isWebkit = -> isWebkitCache ?= navigator.userAgent.indexOf('AppleWebKit/') > -1
