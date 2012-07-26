jQuery(document).ready ($) ->
  if ($.cookie('hide-news-ticker') != '1')
    $('#news-ticker').show()
    $('#close-news-ticker-link').bind('click', ->
      $('#news-ticker').hide()
      $.cookie('hide-news-ticker', '1', { expires: 7 })
      return false
    )
