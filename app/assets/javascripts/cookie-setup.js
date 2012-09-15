jQuery(document).ready(function($) {
  if ($.cookie('has_mail') == '1') {
    $('#has-mail-notice').show();
  }
});
