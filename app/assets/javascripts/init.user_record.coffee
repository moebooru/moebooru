$ = jQuery

$ ->
  $('.js-user-record-destroy').click (e) ->
    e.preventDefault()
    UserRecord.destroy $(e.target).data('id')
