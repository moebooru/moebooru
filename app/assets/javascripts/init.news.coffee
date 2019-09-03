$ = jQuery

$ ->
  $newsTicker = $("#news-ticker")
  newsDate = $newsTicker.attr("data-date")
  cookieKey = "hide-news-ticker"

  return if $newsTicker.attr("data-news-hide") == "1"

  if Cookies.get(cookieKey) != newsDate
    $newsTicker.show()

  $newsTicker.find(".close-link").click (e) ->
    e.preventDefault()
    $newsTicker.hide()
    Cookies.set cookieKey, newsDate, expires: 365
