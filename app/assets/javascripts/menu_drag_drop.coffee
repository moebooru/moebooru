$ = jQuery

class @MenuDragDrop
  constructor: ->
    @menuLinks = $('#main-menu > ul > li > a')
    @submenus = @menuLinks.siblings('.submenu')
    @submenuLinks = @submenus.find('a')
    @which = null
    @dragStartTarget = null
    @dragStartSubmenu = null
    @dragStarted = false

    @menuLinks.on 'mousedown', @mousedown
    @menuLinks.on 'dragstart', -> false


  menuLinksEnter: (e) =>
    submenu = $(e.currentTarget).siblings('.submenu')
    @submenus.hide()
    @dragStartSubmenu.css 'opacity', ''
    submenu.show()


  startSubmenuEnter: (e) =>
    @dragStartSubmenu.off 'mousemove', @startSubmenuEnter
    @dragStartSubmenu.css 'opacity', ''


  submenuLinkEnter: (e) ->
    $(e.currentTarget).addClass 'hover'


  submenuLinksLeave: (e) ->
    $(e.currentTarget).removeClass 'hover'


  doDragDrop: =>
    @dragStartTarget.off 'mouseleave', @doDragDrop
    @submenus.hide()
    @dragStartSubmenu.css('opacity', '0.4').show()
    @dragStartSubmenu.on 'mousemove', @startSubmenuEnter
    @menuLinks.on 'mouseenter', @menuLinksEnter
    @submenuLinks.on 'mouseenter', @submenuLinksEnter
    @submenuLinks.on 'mouseleave', @submenuLinksLeave
    @dragStarted = true


  endDragDrop: =>
    @submenus.css('opacity', '').hide()
    @dragStartSubmenu.off 'mousemove', @startSubmenuEnter
    @menuLinks.off 'mouseenter', @menuLinksEnter
    @submenuLinks.off 'mouseenter', @submenuLinksEnter
    @submenuLinks.off 'mouseleave', @submenuLinksLeave
    @submenuLinks.removeClass 'hover'
    @dragStarted = false


  mouseup: (e) =>
    $(document).off 'mouseup', @mouseup
    @dragStartTarget.off 'mouseleave', @doDragDrop
    @endDragDrop() if @dragStarted

    target = $(e.target)
    # only trigger click if it's submenu link and the button didn't change.
    # A different, normal click will be triggered if it's different button.
    if @submenus.find(target).length > 0 && @which == e.which
      # if started with middle click, open the target in a new window.
      target.attr 'target', '_blank' if @which == 2
      target[0].click()
      target.attr 'target', null


  mousedown: (e) =>
    @which = e.which
    return if @which !in [1, 2]

    @dragStartTarget = $(e.currentTarget)
    @dragStartSubmenu = @dragStartTarget.siblings('.submenu')
    $(document).on 'mouseup', @mouseup
    @dragStartTarget.on 'mouseleave', @doDragDrop
