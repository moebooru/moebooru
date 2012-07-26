if (jQuery.cookie('hide-news-ticker') != '1')
  jQuery('#news-ticker').show()
  jQuery('#close-news-ticker-link').bind('click', ->
    jQuery('#news-ticker').hide()
    jQuery.cookie('hide-news-ticker', '1', 7))
