(function($) {
  Dmail = {
    respond: function(to) {
      $('#dmail_to_name').val(to);
      var stripped_body = $('#dmail_body').val().replace(/\[quote\](?:.|\n)+?\[\/quote\]\n*/gm, "");
      $('#dmail_body').val("[quote]You said:\n" + stripped_body + "\n[/quote]\n\n");
      $('#response').show();
    },

    expand: function(parent_id, id) {
      notice("Fetching previous messages...")

      $.ajax({
        url: Moebooru.path('/dmail/show_previous_messages'),
        type: 'get',
        data: {
          "id": id,
          "parent_id": parent_id
        }
      }).done(function(data) {
        $('#previous-messages').html(data);
        $('#previous-messages').show();
        notice('Previous messages loaded');
      })
    }
  }
}) (jQuery);
