(($, t) ->
  REMOVE = 0
  GOOD = 1
  GREAT = 2
  FAVORITE = 3

  @Vote = (container, id) ->
    nodes = container.find('*')
    @desc = nodes.filter('.vote-desc')
    @stars = nodes.filter('.star-off')
    @post_score = nodes.filter('#post-score-' + id + ', .post-score')
    @vote_up = nodes.filter('.vote-up')
    @post_id = id
    @label = [
      t('.remove')
      t('.good')
      t('.great')
      t('.fav')
    ]
    @setupEvents()
    @data =
      score: null
      vote: null
    return

  @Vote.prototype =
    set: (vote) ->
      th = this
      notice t('.voting')
      $.ajax(
        url: Moebooru.path('/post/vote.json')
        data:
          id: @post_id
          score: vote
        dataType: 'json'
        type: 'post'
        statusCode: 403: ->
          notice t('js.error') + t('js.denied')
          return
      ).done (data) ->
        th.updateWidget vote, data.posts[0].score
        $('#favorited-by').html Favorite.link_to_users(data.voted_by[FAVORITE])
        notice t('.saved')
        return
      false
    setupEvents: ->
      th = this
      stars = @stars

      get_score = (o) ->
        match = o.match(/star\-(\d)/)
        try
          if match.length == 2
            return parseInt(match[1])
        catch error
        -1

      stars.on 'click', ->
        score = get_score(@className)
        th.set score
      stars.on 'mouseover', ->
        score = get_score(@className)
        i = 1
        while i <= FAVORITE
          star = $(stars[i])
          if i <= score
            star.removeClass 'star-hovered-after'
            star.addClass 'star-hovered-upto'
          else
            star.removeClass 'star-hovered-upto'
            star.addClass 'star-hovered-after'
          if i != score
            star.removeClass 'star-hovered'
            star.addClass 'star-unhovered'
          else
            star.removeClass 'star-unhovered'
            star.removeClass 'star-hovered'
          i++
        th.desc.text th.label[score]
        false
      stars.on 'mouseout', ->
        i = 1
        while i <= FAVORITE
          star = $(stars[i])
          star.removeClass 'star-hovered'
          star.removeClass 'star-unhovered'
          star.removeClass 'star-hovered-after'
          star.removeClass 'star-hovered-upto'
          i++
        th.desc.text ''
        false
      @vote_up.on 'click', ->
        if th.vote < FAVORITE
          return th.set(th.vote + 1)
        false
      $('#add-to-favs > a').on 'click', ->
        th.set FAVORITE
      $('#remove-from-favs > a').on 'click', ->
        th.set GREAT
      return
    updateWidget: (vote, score) ->
      add = $('#add-to-favs')
      rm = $('#remove-from-favs')
      @vote = vote or 0
      @data.score = score
      @data.vote = vote
      i = 1
      while i <= FAVORITE
        star = $(@stars[i])
        if i <= vote
          star.removeClass 'star-set-after'
          star.addClass 'star-set-upto'
        else
          star.removeClass 'star-set-upto'
          star.addClass 'star-set-after'
        i++
      if vote == FAVORITE
        add.hide()
        rm.show()
      else
        add.show()
        rm.hide()
      @post_score.text score
      return
    initShortcut: ->
      th = this
      Mousetrap.bind '`', ->
        th.set REMOVE
        return
      Mousetrap.bind '1', ->
        th.set GOOD
        return
      Mousetrap.bind '2', ->
        th.set GREAT
        return
      Mousetrap.bind '3', ->
        th.set FAVORITE
        return
      return
  return
).call this, jQuery, I18n.scopify('js.vote')
