$ = jQuery

export default class NewsTicker
  cookieKey: 'hide-news-ticker'

  constructor: ->
    $ @initialize


  initialize: =>
    @$newsTicker = $('#news-ticker')
    @newsDate = @$newsTicker.attr('data-date')

    return if @$newsTicker.attr('data-news-hide') == '1'

    @$newsTicker.find('.close-link').click @onCloseLink
    if Cookies.get(@cookieKey) != @newsDate
      @$newsTicker.show()


  onCloseLink: (e) =>
    e.preventDefault()
    @$newsTicker.hide()
    Cookies.set @cookieKey, @newsDate, expires: 365
