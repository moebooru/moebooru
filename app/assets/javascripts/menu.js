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

    // Set link to moderate when there's something in moderation queue.
    set_post_moderate_count: function() {
      var mod_pending = $.cookie('mod_pending');
      if (mod_pending > 0) {
        var mod_link = this.menu.find('.moderate');
        mod_link.text(mod_link.text() + ' (' + mod_pending + ')').addClass('bolded');
      };
    },

    // Highlight current location (based on controller)
    set_highlight: function() {
      var hl_menu_class = '.' + this.menu.data('controller');
      this.menu.find(hl_menu_class).addClass('current-menu');
    },

    /*
     * Sets various forum-related menu:
     * - adds 5 latest topics
     * - sets width of forum submenu.
     * - sets correct class based on read/unread
     */
    sync_forum_menu: function() {
      // Adds 5 latest topics.
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

      // Sets width of forum submenu.
      var forum_submenu = this.menu.find('.forum ul');
      if (forum_submenu.width() >= 200) {
        forum_submenu.css('width', '200px');
        forum_submenu.find('a').css('white-space', 'normal');
      } else {
        forum_submenu.css('width', '');
        forum_submenu.find('a').css('white-space', '');
      };

      // Sets correct class based on read/unread.
      if ($.cookie('forum_updated') == '1') {
        $('#forum-link').addClass('forum-update');
        $('#forum-mark-all-read').show();
      } else {
        $('#forum-link').removeClass('forum-update');
        $('#forum-mark-all-read').hide();
      };
    },

    init: function() {
      this.menu = $('#main-menu');
      this.set_highlight();
      this.set_post_moderate_count();
      this.sync_forum_menu();
      /*
       * Shows #cn
       * FIXME: I have no idea what this is for.
       */
      $('#cn').show();
    }
  };
}) (jQuery);
