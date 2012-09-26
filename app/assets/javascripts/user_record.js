(function($) {
  UserRecord = {
    destroy: function(id) {
      notice('Deleting record #' + id)

      $.ajax({
        url: Moebooru.path('/user_record/destroy.json'),
        type: 'delete',
        data: {
          "id": id
        }
      }).done(function() {
        notice('Record deleted');
      }).fail(function() {
        notice('Access denied');
      });
    }
  }
}) (jQuery);
