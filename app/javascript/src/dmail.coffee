$ = jQuery
t = I18n.scopify('js.dmail')

export default class Dmail
  constructor: ->
    $(document).on 'click', '.js-dmail--respond', @respond
    $(document).on 'click', '.js-dmail--expand', @expand


  respond: (e) ->
    e.preventDefault()

    to = e.currentTarget.dataset.dmailName

    $('#dmail_to_name').val to
    strippedBody = $('#dmail_body').val().replace(/\[quote\](?:.|\n)+?\[\/quote\]\n*/gm, '')
    $('#dmail_body').val "[quote]You said:\n#{strippedBody}\n[/quote]\n\n"
    $('#response').show()


  expand: (e) ->
    e.preventDefault()

    parentId = e.currentTarget.dataset.dmailParentId
    id = e.currentTarget.dataset.dmailId

    notice t('.fetch_prev_msg')

    $.ajax
      url: Moebooru.path('/dmail/show_previous_messages')
      type: 'get'
      data:
        id: id
        parent_id: parentId
    .done (data) ->
      $('#previous-messages').html data
      $('#previous-messages').show()
      notice t('.prev_msg_loaded')
