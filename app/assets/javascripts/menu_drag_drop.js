(function($) {
MenuDragDrop = {
  menu_links: null,
  submenus: null,
  submenu_links: null,
  which: null,
  drag_start_target: null,
  drag_start_submenu: null,
  drag_started: false,
  menu_links_enter: function(e) {
    var submenu = $(e.currentTarget).siblings('.submenu');
    this.submenus.hide();
    this.drag_start_submenu.css('opacity', '');
    submenu.show();
  },
  start_submenu_enter: function(e) {
    this.drag_start_submenu.off('mousemove', $.proxy(this.start_submenu_enter, this));
    this.drag_start_submenu.css('opacity', '');
  },
  submenu_links_enter: function(e) {
    $(e.currentTarget).addClass('hover');
  },
  submenu_links_leave: function(e) {
    $(e.currentTarget).removeClass('hover');
  },
  do_drag_drop: function() {
    this.drag_start_target.off('mouseleave', $.proxy(this.do_drag_drop, this));
    this.submenus.hide();
    this.drag_start_submenu.css('opacity', '0.4').show();
    this.drag_start_submenu.on('mousemove', $.proxy(this.start_submenu_enter, this));
    this.menu_links.on('mouseenter', $.proxy(this.menu_links_enter, this));
    this.submenu_links.on('mouseenter', $.proxy(this.submenu_links_enter, this));
    this.submenu_links.on('mouseleave', $.proxy(this.submenu_links_leave, this));
    this.drag_started = true;
  },
  end_drag_drop: function() {
    this.submenus.css('opacity', '').hide();
    this.drag_start_submenu.off('mousemove', $.proxy(this.start_submenu_enter, this));
    this.menu_links.off('mouseenter', $.proxy(this.menu_links_enter, this));
    this.submenu_links.off('mouseenter', $.proxy(this.submenu_links_enter, this));
    this.submenu_links.off('mouseleave', $.proxy(this.submenu_links_leave, this));
    this.submenu_links.removeClass('hover');
    this.drag_started = false;
  },
  mouseup: function(e) {
    $(document).off('mouseup', $.proxy(this.mouseup, this));
    this.drag_start_target.off('mouseleave', $.proxy(this.do_drag_drop, this));
    if (this.drag_started) {
      this.end_drag_drop();
    }
    var target = $(e.target);
    // only trigger click if it's submenu link and the button didn't change.
    // A different, normal click will be triggered if it's different button.
    if (this.submenus.find(target).length > 0 && this.which == e.which) {
      // if started with middle click, open the target in a new window.
      if (this.which == '2') {
        target.attr('target', '_blank');
      };
      target[0].click();
      target.attr('target', null);
    };
  },
  mousedown: function(e) {
    this.which = e.which;
    if (this.which != '1' && this.which != '2') {
      return;
    };
    this.drag_start_target = $(e.currentTarget);
    this.drag_start_submenu = this.drag_start_target.siblings('.submenu');
    $(document).on('mouseup', $.proxy(this.mouseup, this));
    this.drag_start_target.on('mouseleave', $.proxy(this.do_drag_drop, this));
  },
  init: function() {
    this.menu_links = $('#main-menu > ul > li > a');
    this.submenus = this.menu_links.siblings('.submenu');
    this.submenu_links = this.submenus.find('a');
    this.menu_links.on('mousedown', $.proxy(this.mousedown, this));
    this.menu_links.on('dragstart', function() { return false; });
  }
};
}) (jQuery);
