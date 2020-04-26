$ = jQuery

### If initial is true, this is a notice set by the notice cookie and not a
# realtime notice from user interaction.
###

window.notice = (msg, initial) ->

  ### If this is an initial notice, and this screen has a dedicated notice
  # container other than the floating notice, use that and don't disappear
  # it.
  ###

  if initial
    static_notice = $('#static_notice')
    if static_notice
      static_notice.html msg
      static_notice.show()
      return
  start_notice_timer()
  $('#notice').html msg
  $('#notice-container').show()
  return

window.ClearNoticeTimer = null


window.start_notice_timer = ->
  if window.ClearNoticeTimer
    window.clearTimeout window.ClearNoticeTimer
  window.ClearNoticeTimer = window.setTimeout((->
    $('#notice-container').hide()
    return
  ), 5000)
  return


$ ->
  notice = Cookies.get "notice"
  return unless notice && notice != ""

  window.notice notice, true
  Cookies.remove "notice"
