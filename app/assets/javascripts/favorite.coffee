$ = jQuery

usersLinks = (users) ->
  users.map (user) ->
    userLink(user.id, user.name)
  .join(", ")


userLink = (id, name) ->
  "<a href='#{Moebooru.path("/user/show/#{id}")}'>#{name}</a>"


$(document).on "click", "#remaining-favs-link a", (e) ->
  e.preventDefault()

  $(e.target).closest("span").hide()
  $("#remaining-favs").show()


window.Favorite = link_to_users: (users) ->
  return I18n.t "js.noone" if users.length == 0

  html = usersLinks users.slice(0, 6)

  if users.length > 6
    html += "<span id='remaining-favs' style='display: none;'>, #{usersLinks users.slice(6)}</span>"
    html += " <span id='remaining-favs-link'>(<a href='#'>#{users.length - 6} more</a>)</span>"

  html
