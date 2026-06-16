/* global Moebooru, menu, notice, jQuery, I18n */
const $ = jQuery;
const t = I18n.scopify('js.forum');

window.Forum = {
  mark_all_read () {
    $.ajax(Moebooru.path('/forum/mark_all_read')).done(function () {
      document.getElementById('forum-post-last-read-at').text = JSON.stringify((new Date()).toISOString());
      $('span.forum-topic').removeClass('unread-topic');
      $('div.forum-update').removeClass('forum-update');
      menu.syncForumMenu(true);
      notice(t('.mark_as_read'));
    });
  },
  quote (id) {
    $.ajax({
      url: Moebooru.path('/forum/show.json'),
      type: 'get',
      data: { id }
    }).done(function (resp) {
      const strippedBody = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, '');
      $('#reply').show();
      $('#forum_post_body').val((i, val) => (
        val + '[quote]' + resp.creator + ' ' + t('js.said') + '\n' + strippedBody + '\n[/quote]\n\n'
      ));
      $('#respond-link')?.hide();
      $('#forum_post_body')?.focus();
    }).fail(function () {
      notice(t('.quote_error'));
    });
  }
};
