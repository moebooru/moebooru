(function($) {
  Comment = {
    spoiler: function(obj) {
      var text = $(obj).next('.spoilertext');
      var warning = $(obj).children('.spoilerwarning');
      obj.hide();
      text.show();
    },

    flag: function(id) {
      if(!confirm('Flag this comment?'))
        return;

      notice('Flagging comment for deletion...')

      $.ajax({
        url: Moebooru.path('/comment/mark_as_spam.json'),
        type: 'post',
        data: {
          'id': id,
          'comment[is_spam]': 1
        }
      }).done(function(resp) {
        notice('Comment flagged for deletion');
      }).fail(function(resp) {
        var resp = $.parseJSON(resp.responseText)
        notice('Error: ' + resp.reason);
      })
    },

    quote: function(id) {
      $.ajax({
        url: Moebooru.path('/comment/show.json'),
        type: 'get',
        data: {
          'id': id
        }
      }).done(function(resp) {
        var stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\](?:\r\n|\r|\n)*/gm, '')
        var body = '[quote]' + resp.creator + ' said:\n' + stripped_body + '\n[/quote]\n\n'
        $('#reply-' + resp.post_id).show()
        if ($('#respond-link-' + resp.post_id)) {
          $('#respond-link-' + resp.post_id).hide()
        }
        var reply_box = $('#reply-text-' + resp.post_id)
        reply_box.val(reply_box.val() + body);
        reply_box.focus();
      }).fail(function() {
        notice('Error quoting comment')
      });
    },

    destroy: function(id) {
      if (!confirm('Are you sure you want to delete this comment?') ) {
        return;
      }
      $.ajax({
        url: Moebooru.path('/comment/destroy.json'),
        type: 'post',
        data: { 'id': id }
      }).done(function(resp) {
        document.location.reload()
      }).fail(function(resp) {
        var resp = $.parseJSON(resp.responseText)
        notice('Error deleting comment: ' + resp.reason)
      });
    },

    show_reply_form: function(post_id)
    {
      $('#respond-link-' + post_id).hide();
      $('#reply-' + post_id).show();
      $('#reply-' + post_id).find('textarea').focus();
    }
  }
}) (jQuery);
