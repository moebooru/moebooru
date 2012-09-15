jQuery(document).ready(function($) {
  if ($.cookie('has_mail') == '1') {
    $('#has-mail-notice').show();
  };

  if (parseInt($.cookie('mod_pending')) > 0) {
    $('#moderate').addClass('mod-pending');
  };
});
