export default class TagScript
  constructor: ->
    TagEditArea = null

  load: ->
    @TagEditArea.value = Cookie.get('tag-script')
    return

  save: ->
    Cookie.put 'tag-script', @TagEditArea.value
    return

  init: (element, x) ->
    @TagEditArea = element
    @load()
    @TagEditArea.observe 'change', (e) =>
      @save()
      return
    @TagEditArea.observe 'focus', (e) ->
      Post.reset_tag_script_applied()
      return

    # This mostly keeps the tag script field in sync between windows, but it
    # doesn't work in Opera, which sends focus events before blur events.
    Event.on window, 'unload', =>
      @save()
      return
    document.observe 'focus', (e) =>
      @load()
      return
    return

  parse: (script) ->
    script.match /\[.+?\]|\S+/g

  test: (tags, predicate) ->
    split_pred = predicate.match(/\S+/g)
    is_true = true
    split_pred.each (x) ->
      if x[0] == '-'
        if tags.include(x.substr(1, 100))
          is_true = false
          throw $break
      else
        if !tags.include(x)
          is_true = false
          throw $break
      return
    is_true

  process: (tags, command) ->
    if command.match(/^\[if/)
      match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/)
      if @test(tags, match[1])
        @process tags, match[2]
      else
        tags
    else if command == '[reset]'
      []
    else if command[0] == '-' and command.indexOf('-pool:') != 0
      tags.reject (x) ->
        x == command.substr(1, 100)
    else
      tags.push command
      tags
  run: (post_ids, tag_script, finished) ->
    if !Object.isArray(post_ids)
      post_ids = $A([ post_ids ])
    commands = @parse(tag_script) or []
    posts = new Array
    post_ids.each (post_id) =>
      post = Post.posts.get(post_id)
      old_tags = post.tags.join(' ')
      commands.each (x) =>
        post.tags = @process(post.tags, x)
        return
      posts.push
        id: post_id
        old_tags: old_tags
        tags: post.tags.join(' ')
      return
    notice 'Updating ' + posts.length + (if post_ids.length == 1 then ' post' else ' posts')
    Post.update_batch posts, finished
    return
