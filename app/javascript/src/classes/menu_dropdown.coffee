$ = jQuery

export default class MenuDropdown
  constructor: ->
    $(document).on 'click', '.submenu-button', @onToggle
    $(document).on 'click', @onDocumentClick


  hide: =>
    return unless @current?

    @current.$menu.hide()
    @current = null


  onDocumentClick: (e) =>
    return unless @current?

    if e?.target? && $(e.target).closest(@current.link).length > 0
      return

    @hide()


  onToggle: (e) =>
    e.preventDefault()

    link = e.currentTarget
    openLink = @current?.link

    @hide()

    return if openLink == link

    $menu = $(link).siblings('.submenu')
    $menu.show()
    @current = { link, $menu }
