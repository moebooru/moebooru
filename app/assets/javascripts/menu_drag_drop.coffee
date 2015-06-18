(($) ->
  window.MenuDragDrop =
    menu_links: null
    submenus: null
    submenu_links: null
    which: null
    drag_start_target: null
    drag_start_submenu: null
    drag_started: false
    menu_links_enter: (e) ->
      submenu = $(e.currentTarget).siblings('.submenu')
      @submenus.hide()
      @drag_start_submenu.css 'opacity', ''
      submenu.show()
      return
    start_submenu_enter: (e) ->
      @drag_start_submenu.off 'mousemove', $.proxy(@start_submenu_enter, this)
      @drag_start_submenu.css 'opacity', ''
      return
    submenu_links_enter: (e) ->
      $(e.currentTarget).addClass 'hover'
      return
    submenu_links_leave: (e) ->
      $(e.currentTarget).removeClass 'hover'
      return
    do_drag_drop: ->
      @drag_start_target.off 'mouseleave', $.proxy(@do_drag_drop, this)
      @submenus.hide()
      @drag_start_submenu.css('opacity', '0.4').show()
      @drag_start_submenu.on 'mousemove', $.proxy(@start_submenu_enter, this)
      @menu_links.on 'mouseenter', $.proxy(@menu_links_enter, this)
      @submenu_links.on 'mouseenter', $.proxy(@submenu_links_enter, this)
      @submenu_links.on 'mouseleave', $.proxy(@submenu_links_leave, this)
      @drag_started = true
      return
    end_drag_drop: ->
      @submenus.css('opacity', '').hide()
      @drag_start_submenu.off 'mousemove', $.proxy(@start_submenu_enter, this)
      @menu_links.off 'mouseenter', $.proxy(@menu_links_enter, this)
      @submenu_links.off 'mouseenter', $.proxy(@submenu_links_enter, this)
      @submenu_links.off 'mouseleave', $.proxy(@submenu_links_leave, this)
      @submenu_links.removeClass 'hover'
      @drag_started = false
      return
    mouseup: (e) ->
      $(document).off 'mouseup', $.proxy(@mouseup, this)
      @drag_start_target.off 'mouseleave', $.proxy(@do_drag_drop, this)
      if @drag_started
        @end_drag_drop()
      target = $(e.target)
      # only trigger click if it's submenu link and the button didn't change.
      # A different, normal click will be triggered if it's different button.
      if @submenus.find(target).length > 0 and @which == e.which
        # if started with middle click, open the target in a new window.
        if @which == 2
          target.attr 'target', '_blank'
        target[0].click()
        target.attr 'target', null
      return
    mousedown: (e) ->
      @which = e.which
      if @which != 1 and @which != 2
        return
      @drag_start_target = $(e.currentTarget)
      @drag_start_submenu = @drag_start_target.siblings('.submenu')
      $(document).on 'mouseup', $.proxy(@mouseup, this)
      @drag_start_target.on 'mouseleave', $.proxy(@do_drag_drop, this)
      return
    init: ->
      @menu_links = $('#main-menu > ul > li > a')
      @submenus = @menu_links.siblings('.submenu')
      @submenu_links = @submenus.find('a')
      @menu_links.on 'mousedown', $.proxy(@mousedown, this)
      @menu_links.on 'dragstart', ->
        false
      return
  return
) jQuery
