$ = jQuery

export default class UserRecord
  constructor: ->
    $(document).on 'click', '.js-user-record-destroy', @onDestroy


  destroy: (id) =>
    notice "Deleting record ##{id}"
    $.ajax
      url: Moebooru.path('/user_record/destroy.json')
      type: 'delete'
      data: 'id': id
    .done ->
      notice 'Record deleted'
    .fail ->
      notice 'Access denied'


  onDestroy: (e) =>
    e.preventDefault()
    @destroy($(e.currentTarget).data('id'))
