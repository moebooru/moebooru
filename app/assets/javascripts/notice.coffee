$ = jQuery

$ ->
  notice = Cookies "notice"
  return unless notice && notice != ""

  window.notice notice, true
  Cookies.remove "notice"
