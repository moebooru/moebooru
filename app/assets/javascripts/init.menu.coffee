$ = jQuery

$ ->
  Menu.init()
  $(document).on 'click', '#main-menu .search-link', (e) ->
    Menu.show_search_box e.currentTarget
