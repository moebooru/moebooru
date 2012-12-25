(function($) {
  $(document).on('click', '#login-link', function() {
    User.run_login(false, {});
  });
  $(document).on('click', '#forum-mark-all-read', function() {
    Forum.mark_all_read();
    return false;
  });
}) (jQuery);
