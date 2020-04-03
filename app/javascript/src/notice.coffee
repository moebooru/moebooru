$ = jQuery

$ ->
  notice = Cookies.get "notice"
  return unless notice && notice != ""

  window.notice notice, true
  Cookies.remove "notice"
