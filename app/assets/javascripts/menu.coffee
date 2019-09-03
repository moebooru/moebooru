$ = jQuery

$(document).on 'click', '#login-link', (e) ->
  e.preventDefault()
  User.run_login false, ->
    window.location = window.location


$(document).on 'click', '#forum-mark-all-read', (e) ->
  e.preventDefault()
  Forum.mark_all_read()



window.Menu =
  menu: null

  setPostModerateCount: ->
    pending = parseInt Cookies.get("mod_pending")
    return unless pending > 0

    link = @menu.find(".moderate")
    link
      .text("#{link.text()} (#{pending})")
      .addClass "bolded"


  setHighlight: ->
    @menu
      .find(".#{@menu.data "controller"}")
      .addClass "current-menu"


  showHelpItem: ->
    @menu
      .find(".help-item.#{@menu.data("controller")}")
      .show()


  show_search_box: (elem) ->
    submenu = $(elem).parents('.submenu')
    search_box = submenu.siblings('.search-box')
    search_text_box = search_box.find('[type="text"]')

    hide = (e) ->
      search_box.hide()
      search_box.removeClass 'is_modal'
      search_text_box.removeClass 'mousetrap'
      return

    show = ->
      $('.submenu').hide()
      search_box.show()
      search_box.addClass 'is_modal'
      search_text_box.addClass('mousetrap').focus()

      document_click_event = (e) ->
        if $(e.target).parents('.is_modal').length == 0 and !$(e.target).hasClass('is_modal')
          hide e
          $(document).off 'mousedown', '*', document_click_event
        return

      $(document).on 'mousedown', '*', document_click_event
      Mousetrap.bind 'esc', hide
      return

    show()
    false
  sync_forum_menu: (reload = false) ->
    self = this
    if reload
      $.get Moebooru.path('/forum.json'), { latest: 1 }, (resp) =>
        window.forumMenuItems = resp
        @sync_forum_menu(false)

      return

    window.forumMenuItems ||= JSON.parse(document.getElementById("forum-posts-latest").text).forum_posts

    last_read = Cookies.getJSON('forum_post_last_read_at')
    forum_menu_items = window.forumMenuItems
    forum_submenu = $('li.forum ul.submenu', self.menu)
    forum_items_start = forum_submenu.find('.forum-items-start').show()

    create_forum_item = (post_data) ->
      $ '<li/>', html: $('<a/>',
        href: Moebooru.path('/forum/show/' + post_data.id + '?page=' + post_data.pages)
        text: post_data.title
        title: post_data.title
        class: if post_data.updated_at > last_read then 'unread-topic' else null)

    # Reset latest topics.
    forum_items_start.nextAll().remove()
    if forum_menu_items.length > 0
      $.each forum_menu_items, (_i, post_data) ->
        forum_submenu.append create_forum_item(post_data)
        forum_items_start.show()
        return
      # Set correct class based on read/unread.
      if forum_menu_items.first().updated_at > last_read
        $('#forum-link').addClass 'forum-update'
        $('#forum-mark-all-read').show()
      else
        $('#forum-link').removeClass 'forum-update'
        $('#forum-mark-all-read').hide()

  init: ->
    @menu = $('#main-menu')
    return if @menu.length == 0

    @setHighlight()
    @setPostModerateCount()
    @sync_forum_menu()
    @showHelpItem()
