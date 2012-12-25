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

    toggle: function(elem) {
      var submenu = $(elem).parent().siblings('.submenu'),
        submenu_hid = (submenu.css('display') == 'none');
      this.hide();
      if (submenu_hid) {
        submenu.show();
        $(document).on('click', Menu.hide);
      }
    },

    hide: function() {
      $('.submenu').hide();
      $(document).off('click', Menu.hide);
    },

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

    // Hide irrelevant help menu items
    hide_help_items: function() {
      var nohide_menu_class = '.help-item.' + this.menu.data('controller');
      this.menu.find('.help-item').hide();
      this.menu.find(nohide_menu_class).show();
    },

    show_search_box: function(elem) {
      var
        submenu = $(elem).parents('.submenu'),
        search_box = submenu.siblings('.search-box'),
        search_text_box = search_box.find('[type="text"]'),
        hide = function(e) {
          search_box.hide();
          search_box.removeClass('is_modal');
          search_text_box.removeClass('mousetrap');
          $('.submenu').show();
        },
        show = function() { $('.submenu').hide();
          search_box.show();
          search_box.addClass('is_modal');
          search_text_box.addClass('mousetrap').focus();
          $(document).click(function(e) {
            if ($(e.target).parents('.is_modal').length == 0 && !$(e.target).hasClass('is_modal')) {
              hide(e);
            };
          });
          Mousetrap.bind('esc', hide);
        };
      show();
      return false;
    },

    /*
     * Sets various forum-related menu:
     * - adds latest topics
     * - sets correct class based on read/unread
     */
    sync_forum_menu: function() {
      // Adds latest topics.
      var forum_menu_items = $.parseJSON($.cookie('current_forum_posts'));
      var create_forum_item = function(forum_json) {
        var link_text = forum_json[0].length > 20 ? forum_json[0].substr(0,20) + '...' : forum_json[0];
        return $('<li/>', {
          html: $('<a/>', {
            href: Moebooru.path('/forum/show/' + forum_json[1] + '?page=' + forum_json[3]),
            text: link_text,
            title: forum_json[0],
            class: forum_json[2] ? 'unread-topic' : null
          }),
        });
      };
      this.menu.find('.forum-items-start').nextAll().remove();
      var menu_items_num = forum_menu_items.length;
      if (menu_items_num > 0) {
        for (var i = menu_items_num - 1; i >=0; i--) {
          this.menu.find('.forum-items-start').after(create_forum_item(forum_menu_items[i]));
        };
        this.menu.find('.forum-items-start').show();
      }

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
      this.hide_help_items();
      /*
       * Shows #cn
       * FIXME: I have no idea what this is for.
       */
      $('#cn').show();
    }
  };
}) (jQuery);
