(function($) {
  $(document).on('click', '#login-link', function() {
    User.run_login(false, {});
    return false;
  });
  $(document).on('click', '#forum-mark-all-read', function() {
    Forum.mark_all_read();
    return false;
  });

  Menu = {
    menu: null,

    toggle: function(e) {
      target = $(e.target);
      if (target.hasClass('submenu-button')) {
        var submenu = target.siblings('.submenu'),
          submenu_hid = (submenu.css('display') == 'none');
        $('.submenu').hide();
        if (submenu_hid) {
          submenu.show();
        }
        return false;
      } else if (target.parents('.submenu').length == 0 || e.which != '2') {
        $('.submenu').hide();
      }
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
        },
        show = function() { $('.submenu').hide();
          search_box.show();
          search_box.addClass('is_modal');
          search_text_box.addClass('mousetrap').focus();
          var document_click_event = function(e) {
            if ($(e.target).parents('.is_modal').length == 0 && !$(e.target).hasClass('is_modal')) {
              hide(e);
              $(document).off('mousedown', '*', document_click_event);
            };
          };
          $(document).on('mousedown', '*', document_click_event);
          Mousetrap.bind('esc', hide);
        };
      show();
      return false;
    },

    /*
     * Sets various forum-related menu:
     * - reset latest topics
     * - set correct class based on read/unread
     */
    sync_forum_menu: function() {
      var
        self = this,
        last_read = $.parseJSON($.cookie("forum_post_last_read_at")),
        forum_menu_items = $.parseJSON($.cookie("forum_posts")),
        forum_submenu = $("li.forum ul.submenu", self.menu),
        forum_items_start = forum_submenu.find('.forum-items-start').show();
        create_forum_item = function(post_data) {
          return $("<li/>", {
            html: $("<a/>", {
              href: Moebooru.path("/forum/show/" + post_data.id + "?page=" + post_data.pages),
              text: post_data.title,
              title: post_data.title,
              class: (post_data.updated_at > last_read) ? "unread-topic" : null
              })
          })
        }
      // Reset latest topics.
      forum_items_start.nextAll().remove();
      if (forum_menu_items.length > 0) {
        $.each(forum_menu_items, function(_i, post_data) {
          forum_submenu.append(create_forum_item(post_data))
          forum_items_start.show();
        })
      }

      // Set correct class based on read/unread.
      if (forum_menu_items.first().updated_at > last_read) {
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
