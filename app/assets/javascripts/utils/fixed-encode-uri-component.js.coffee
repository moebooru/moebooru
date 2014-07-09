# https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURIComponent
window.fixedEncodeURIComponent = (str) ->
  encodeURIComponent(str).replace(/[!'()]/g, escape).replace(/\*/g, "%2A")
