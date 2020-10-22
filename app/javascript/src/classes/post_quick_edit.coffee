export default class PostQuickEdit
  constructor: (container) ->
    @container = container
    @container.down('form').observe 'submit', @submit_event
    @container.down('.cancel').observe 'click', (e) =>
      e.preventDefault()
      @hide()
      return
    @container.down('#post_tags').observe 'keydown', (e) =>
      if e.keyCode == Event.KEY_ESC
        e.stop()
        @hide()
        return
      if e.keyCode != Event.KEY_RETURN
        return
      @submit_event e
      return

  show: (post_id) ->
    Post.hover_info_pin post_id
    post = Post.posts.get(post_id)
    @post_id = post_id
    @old_tags = post.tags.join(' ')
    @container.down('#post_tags').value = post.tags.join(' ') + ' rating:' + post.rating.substr(0, 1) + ' '
    @container.show()
    @container.down('#post_tags').focus()
    return

  hide: ->
    @container.hide()
    Post.hover_info_pin null
    return

  submit_event: (e) =>
    e.stop()
    @hide()
    Post.update_batch [{
      id: @post_id
      tags: @container.down('#post_tags').value
      old_tags: @old_tags
    }], =>
      notice 'Post updated'
      @hide()
      return
    return
