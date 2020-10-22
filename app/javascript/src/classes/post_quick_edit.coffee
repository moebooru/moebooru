export default class PostQuickEdit
  constructor: (selector) ->
    @container = document.querySelector(selector)
    @container.querySelector('form').addEventListener 'submit', @onSubmit
    @container.querySelector('.cancel').addEventListener 'click', @onCancelClick
    @container.querySelector('#post_tags').addEventListener 'keydown', @onInputKeydown


  hide: ->
    $(@container).hide()
    Post.hover_info_pin null


  onCancelClick: (e) =>
    e.preventDefault()
    @hide()

    return


  onInputKeydown: (e) =>
    switch e.keyCode
      when 13 # enter
        @onSubmit(e)
      when 27 # escape
        e.preventDefault()
        @hide()

    return


  onSubmit: (e) =>
    e.preventDefault()

    @hide()

    postData =
      id: @postId
      tags: @container.querySelector('#post_tags').value
      old_tags: @oldTags

    Post.update_batch [postData], ->
      notice 'Post updated'

    return


  show: (postId) ->
    Post.hover_info_pin postId

    post = Post.posts.get(postId)

    @postId = postId
    @oldTags = post.tags.join(' ')

    $(@container).show()
    inputBox = @container.querySelector('#post_tags')
    inputBox.value = "#{post.tags.join(' ')} rating:#{post.rating.substr(0, 1)} "
    inputBox.focus()
