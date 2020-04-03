(($, t) ->
  window.Forum =
    mark_all_read: ->
      $.ajax(url: Moebooru.path('/forum/mark_all_read')).done ->
        $('span.forum-topic').removeClass 'unread-topic'
        $('div.forum-update').removeClass 'forum-update'
        Menu.sync_forum_menu(true)
        notice t('.mark_as_read')
        return
      return
    quote: (id) ->
      $.ajax(
        url: Moebooru.path('/forum/show.json')
        type: 'get'
        data: 'id': id).done((resp) ->
        stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, '')
        $('#reply').show()
        $('#forum_post_body').val (i, val) ->
          val + '[quote]' + resp.creator + ' ' + t('js.said') + '\n' + stripped_body + '\n[/quote]\n\n'
        if $('#respond-link')
          $('#respond-link').hide()
        if $('#forum_post_body')
          $('#forum_post_body').focus()
        return
      ).fail ->
        notice t('.quote_error')
        return
      return
  return
) jQuery, I18n.scopify('js.forum')
