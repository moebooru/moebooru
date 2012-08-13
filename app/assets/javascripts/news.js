jQuery(document).ready(function($) {
  if ($.cookie('hide-news-ticker') !== '1') {
    $('#news-ticker').show();
    $('#close-news-ticker-link').on('click', function() {
      $('#news-ticker').hide();
      $.cookie('hide-news-ticker', '1', {
        expires: 7
      });
      return false;
    });
  };
});
