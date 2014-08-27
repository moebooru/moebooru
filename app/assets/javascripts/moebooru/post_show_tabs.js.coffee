#= require moebooru

jQuery(document).ready ($) ->
  window.Moebooru.postShowTabs =
    editTab: $ "#edit"
    commentsTab: $ "#comments"
    showEditTab: (e) ->
      e.preventDefault()
      @editTab.show()
      @commentsTab.hide()
      $.cookie "show_defaults_to_edit", 1
      ($ "#post_tags").focus()
    showCommentsTab: (e) ->
      e.preventDefault()
      @editTab.hide()
      @commentsTab.show()
      $.cookie "show_defaults_to_edit", 0
      ($ "#comments textarea").focus()
    initialize: ->
      ($ ".js-posts-show-edit-tab").click $.proxy(@showEditTab, this)
      ($ ".js-posts-show-comments-tab").click $.proxy(@showCommentsTab, this)
