jQuery(document).ready(function($) {
  Menu.init();
  $(document).on('click', '#main-menu .search-link', function(e) { return Menu.show_search_box(e.currentTarget); });
});
