(($, t) ->
  window.Comment =
    spoiler: (obj) ->
      text = $(obj).next('.spoilertext')
      warning = $(obj).children('.spoilerwarning')
      obj.hide()
      text.show()
      return
    flag: (id) ->
      if !confirm(t('.flag_ask'))
        return
      notice t('.flag_process')
      $.ajax(
        url: Moebooru.path('/comment/mark_as_spam.json')
        type: 'post'
        data:
          'id': id
          'comment[is_spam]': 1).done((resp) ->
        notice t('.flag_notice')
        return
      ).fail (resp) ->
        resp = $.parseJSON(resp.responseText)
        notice t('js.error') + resp.reason
        return
      return
    quote: (id) ->
      $.ajax(
        url: Moebooru.path('/comment/show.json')
        type: 'get'
        data: 'id': id).done((resp) ->
        stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\](?:\r\n|\r|\n)*/gm, '')
        body = '[quote]' + resp.creator + ' ' + t('js.said') + '\n' + stripped_body + '\n[/quote]\n\n'
        $('#reply-' + resp.post_id).show()
        if $('#respond-link-' + resp.post_id)
          $('#respond-link-' + resp.post_id).hide()
        reply_box = $('#reply-text-' + resp.post_id)
        reply_box.val reply_box.val() + body
        reply_box.focus()
        return
      ).fail ->
        notice t('.quote_error')
        return
      return
    destroy: (id) ->
      if !confirm(t('.delete_ask'))
        return
      $.ajax(
        url: Moebooru.path('/comment/destroy.json')
        type: 'post'
        data: 'id': id).done((resp) ->
        document.location.reload()
        return
      ).fail (resp) ->
        resp = $.parseJSON(resp.responseText)
        notice t('.delete_error') + resp.reason
        return
      return
    show_reply_form: (post_id) ->
      $('#respond-link-' + post_id).hide()
      $('#reply-' + post_id).show()
      $('#reply-' + post_id).find('textarea').focus()
      return
  return
) jQuery, I18n.scopify('js.comment')
