(($) ->
  window.UserRecord = destroy: (id) ->
    notice 'Deleting record #' + id
    $.ajax(
      url: Moebooru.path('/user_record/destroy.json')
      type: 'delete'
      data: 'id': id).done(->
      notice 'Record deleted'
      return
    ).fail ->
      notice 'Access denied'
      return
    return
  return
) jQuery
