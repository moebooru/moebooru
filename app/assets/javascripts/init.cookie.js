jQuery(document).ready(function($) {
  // Check if there's new dmail.
  if ($.cookie('has_mail') == '1') {
    $('#has-mail-notice').show();
  };

  // Check if there's new comment.
  if ($.cookie('comments_updated') == '1') {
    $('#comments-link').addClass('comments-update')
    $('#comments-link').addClass('bolded');
  };

  // Show block/ban reason if the user is blocked/banned.
  if ($.cookie('block_reason') && $.cookie('block_reason') != '') {
    $('#block-reason').text($.cookie('block_reason')).show();
  };

  // Check if there's any pending post moderation queue.
  if ($.cookie('mod_pending', Number) > 0) {
    $('#moderate').addClass('mod-pending');
  };
});
