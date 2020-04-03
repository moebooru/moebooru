$ = jQuery

show = (e) ->
  e.preventDefault()
  return if e.which != 1

  link = $(e.target)
  menu = link.siblings(".submenu")

  return if menu.is(":visible")

  menu.show()

  hide = ->
    $(document).one "click", (e) ->
      if e.which == 1
        menu.hide()
      else
        setTimeout hide, 100

  setTimeout hide, 100

$ ->
  $(".submenu-button").click show
