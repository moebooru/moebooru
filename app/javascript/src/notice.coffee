$ = jQuery


export default class Notice
  constructor: ->
    $ @initialize


  hide: =>
    $('#notice-container').hide()


  initialize: =>
    msg = Cookies.get 'notice'

    return unless msg? && msg != ''

    @show msg, true
    Cookies.remove 'notice'


  # If initial is true, this is a notice set by the notice cookie and not a
  # realtime notice from user interaction.
  show: (msg, initial) =>
    # If this is an initial notice, and this screen has a dedicated notice
    # container other than the floating notice, use that and don't hide it.
    if initial ? false
      $staticNotice = $('#static_notice')
      if $staticNotice.length > 0
        $staticNotice
          .html(msg)
          .show()
        return

    $('#notice').html msg
    $('#notice-container').show()

    clearTimeout @timeout
    @timeout = setTimeout @hide, 5000
