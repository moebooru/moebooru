jQuery(document).ready(function($) {
  // Check if there's new dmail.
  if ($.cookie('has_mail') == '1') {
    $('#has-mail-notice').show();
  };

  // Check if there's new comment.
  if ($.cookie('comments_updated') == '1') {
    $('#comments-link').addClass('comments-update');
  };

  // Check if there's any pending post moderation queue.
  if (parseInt($.cookie('mod_pending')) > 0) {
    $('#moderate').addClass('mod-pending');
  };
});
