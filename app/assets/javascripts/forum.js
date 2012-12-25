(function($) {
  Forum = {
    mark_all_read: function() {
      $.ajax({
        url: Moebooru.path('/forum/mark_all_read'),
      }).done(function() {
        $('span.forum-topic').removeClass('unread-topic');
        $('div.forum-update').removeClass('forum-update');
        Menu.sync_forum_menu();
        notice("Marked all topics as read");
      });
    },
    quote: function(id) {
      $.ajax({
        url: Moebooru.path('/forum/show.json'),
        type: 'get',
        data: {
          'id': id
        }
      }).done(function(resp) {
        var stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, '');
        $('#reply').show();
        $('#forum_post_body').val(function(i, val) { return val + '[quote]' + resp.creator + ' said:\n' + stripped_body + '\n[/quote]\n\n'; });
        if($('#respond-link'))
          $('#respond-link').hide();
        if($('#forum_post_body'))
          $('#forum_post_body').focus();
      }).fail(function() {
        notice("Error quoting forum post");
      });
    }
  }
}) (jQuery);
