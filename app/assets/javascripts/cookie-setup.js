jQuery(document).ready(function($) {
  // Check if there's new dmail.
  if ($.cookie('has_mail') == '1') {
    $('#has-mail-notice').show();
  };

  // Check if there's any pending post moderation queue.
  if (parseInt($.cookie('mod_pending')) > 0) {
    $('#moderate').addClass('mod-pending');
  };
});
