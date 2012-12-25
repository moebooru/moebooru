(function($) {
  $(document).on('click', '#login-link', function() {
    User.run_login(false, {});
  });
  $(document).on('click', '#forum-mark-all-read', function() {
    Forum.mark_all_read();
    return false;
  });

  Menu = {
    menu: null,

    // Highlight current location (based on controller)
    set_highlight: function() {
      var hl_menu_class = '.' + this.menu.data('controller');
      this.menu.find(hl_menu_class).addClass('current-menu');
    },

    /*
     * Sets various forum-related menu:
     * - adds 5 latest topics
     * - set correct class based on read/unread
     */
    sync_forum_menu: function() {
      var forum_menu_items = $.parseJSON($.cookie('current_forum_posts'));
      var create_forum_item = function(forum_json) {
        return $('<li/>', {
          html: $('<a/>', {
            href: Moebooru.path('/forum/show/' + forum_json[1] + '?page=' + forum_json[3]),
            text: forum_json[0],
            class: forum_json[2] ? 'unread-topic' : ' '
          }),
        });
      };
      this.menu.find('.forum-items-start').nextAll().remove();
      var menu_items_num = forum_menu_items.length > 5 ? 5 : forum_menu_items.length;
      for (var i = menu_items_num - 1; i >=0; i--) {
        this.menu.find('.forum-items-start').after(create_forum_item(forum_menu_items[i]));
      };
      var forum_submenu = this.menu.find('.forum ul');
      if (forum_submenu.width() > 200) {
        forum_submenu.css('width', 200)
        forum_submenu.find('a').css('white-space', 'normal');
      };
    },

    init: function() {
      this.menu = $('#main-menu');
      this.set_highlight();
      this.sync_forum_menu();
      /*
       * Shows #cn
       * FIXME: I have no idea what this is for.
       */
      $('#cn').show();
    }
  };
}) (jQuery);
