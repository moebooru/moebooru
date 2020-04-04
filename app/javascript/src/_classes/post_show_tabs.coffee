$ = jQuery

export default class PostShowTabs
  constructor: ->
    $ @initialize


  initialize: =>
    @editTab = $('#edit')
    @commentsTab = $('#comments')

    $('.js-posts-show-edit-tab').click @showEditTab
    $('.js-posts-show-comments-tab').click @showCommentsTab

    if (
      $('.js-posts-show-edit-tab').length > 0 &&
      $('.js-posts-show-comments-tab').length > 0 &&
      Cookies.get('show_defaults_to_edit') == '1' &&
      window.location.hash != '#comments' &&
      !window.location.hash.match(/^#c[0-9]+$/)
    )
      @editTab.show()
      @commentsTab.hide()


  showEditTab: (e) =>
    e.preventDefault()

    @editTab.show()
    @commentsTab.hide()
    Cookies.set 'show_defaults_to_edit', 1
    $('#post_tags').focus()


  showCommentsTab: (e) =>
    e.preventDefault()

    @editTab.hide()
    @commentsTab.show()
    Cookies.set 'show_defaults_to_edit', 0
    $('#comments textarea').focus()
