$ = jQuery

$(document).on "ready page:load", ->
  $newsTicker = $("#news-ticker")
  newsDate = $newsTicker.attr("data-date")
  cookieKey = "hide-news-ticker"

  if Cookies(cookieKey) != newsDate
    $newsTicker.show()

  return if $newsTicker.attr("data-news-hide") == "1"

  $newsTicker.find(".close-link").click (e) ->
    e.preventDefault()
    $newsTicker.hide()
    Cookies cookieKey, newsDate, expires: 365
