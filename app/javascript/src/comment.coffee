$ = jQuery
t = I18n.scopify('js.comment')


export default class Comment
  constructor: ->
    $(document).on 'click', '.js-comment--destroy', @destroy
    $(document).on 'click', '.js-comment--flag', @flag
    $(document).on 'click', '.js-comment--quote', @quote
    $(document).on 'click', '.js-comment--show-reply-form', @showReplyForm
    $(document).on 'click', '.js-comment--spoiler', @spoiler


  spoiler: (e) ->
    $(e.currentTarget)
      .hide()
      .next('.spoilertext').show()


  flag: (e) ->
    e.preventDefault()

    return unless confirm(t('.flag_ask'))

    id = e.currentTarget.dataset.commentId

    notice t('.flag_process')

    $.ajax
      url: Moebooru.path('/comment/mark_as_spam.json')
      type: 'post'
      data:
        id: id
        comment:
          is_spam: 1
    .done (resp) ->
      notice t('.flag_notice')
    .fail (resp) ->
      resp = $.parseJSON(resp.responseText)
      notice "#{t('js.error')}#{resp.reason}"


  quote: (e) ->
    e.preventDefault()

    id = e.currentTarget.dataset.commentId

    $.ajax
      url: Moebooru.path('/comment/show.json')
      type: 'get'
      data:
        id: id
    .done (resp) ->
      strippedBody = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\](?:\r\n|\r|\n)*/gm, '')
      body = "[quote]#{resp.creator} #{t('js.said')}\n#{strippedBody}\n[/quote]\n\n"
      $("#reply-#{resp.post_id}").show()
      $("#respond-link-#{resp.post_id}").hide()
      replyBox = $("#reply-text-#{resp.post_id}")
      replyBox.val "#{replyBox.val()}#{body}"
      replyBox.focus()
    .fail ->
      notice t('.quote_error')


  destroy: (e) ->
    e.preventDefault()

    return unless confirm(t('.delete_ask'))

    id = e.currentTarget.dataset.commentId

    $.ajax
      url: Moebooru.path('/comment/destroy.json')
      type: 'post'
      data:
        id: id
    .done (resp) ->
      document.location.reload()
    .fail (resp) ->
      resp = $.parseJSON(resp.responseText)
      notice "#{t('.delete_error')}#{resp.reason}"


  showReplyForm: (e) ->
    e.preventDefault()

    postId = e.currentTarget.dataset.commentPostId

    $("#respond-link-#{postId}").hide()
    $("#reply-#{postId}")
      .show()
      .find('textarea').focus()
