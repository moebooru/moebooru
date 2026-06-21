$ = jQuery


userLink = (id, name) ->
  "<a href='#{Moebooru.path("/user/show/#{id}")}'>#{name}</a>"


usersLinks = (users) ->
  users.map (user) ->
    userLink(user.id, user.name)
  .join(', ')


export default class Favorite
  constructor: ->
    $(document).on 'click', '.js-favorite--show-more', @onShowMoreFavoritedBy


  linkToUsers: (users) ->
    users ?= []

    return I18n.t('js.noone') if users.length == 0

    html = usersLinks users[0..6]

    if users.length > 6
      html += "<span id='remaining-favs' style='display: none;'>, #{usersLinks users[6..]}</span>"
      html += " <span>(<a href='#' class='js-favorite--show-more'>#{users.length - 6} more</a>)</span>"

    html


  onShowMoreFavoritedBy: (e) =>
    e.preventDefault()

    $(e.target).closest('span').hide()
    $('#remaining-favs').show()
