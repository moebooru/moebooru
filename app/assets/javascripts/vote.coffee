$ = jQuery
t = I18n.scopify('js.vote')

REMOVE = 0
GOOD = 1
GREAT = 2
FAVORITE = 3

getScore = (star) ->
  parseInt(star.dataset.star, 10)


class @Vote
  constructor: (container, id) ->
    nodes = container.find('*')
    @desc = nodes.filter('.vote-desc')
    @stars = nodes.filter('.star-off')
    @post_score = nodes.filter("#post-score-#{id}, .post-score")
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


  set: (vote) =>
    notice t('.voting')
    $.ajax
      url: Moebooru.path('/post/vote.json')
      data:
        id: @post_id
        score: vote
      dataType: 'json'
      type: 'post'
      statusCode: 403: ->
        notice "#{t('js.error')}#{t('js.denied')}"
    .done (data) =>
      @updateWidget vote, data.posts[0].score
      $('#favorited-by').html Favorite.link_to_users(data.voted_by[FAVORITE])
      notice t('.saved')


  setupEvents: =>
    @stars.on 'click', (e) =>
      e.preventDefault()
      score = getScore(e.currentTarget)
      @set score
      return

    @stars.on 'mouseover', (e) => @setMouseover e.currentTarget

    @stars.on 'mouseout', => @setMouseover null

    @vote_up.on 'click', (e) =>
      e.preventDefault()
      @set(@vote + 1) if @vote < FAVORITE
      return

    $('#add-to-favs > a').on 'click', =>
      @set FAVORITE

    $('#remove-from-favs > a').on 'click', =>
      @set GREAT


  updateWidget: (vote, targetScore) =>
    add = $('#add-to-favs')
    rm = $('#remove-from-favs')
    @vote = vote || 0
    @data.score = targetScore
    @data.vote = vote

    for star in @stars
      score = getScore(star)
      $star = $(star)
      if score <= vote
        $star.removeClass 'star-set-after'
        $star.addClass 'star-set-upto'
      else
        $star.removeClass 'star-set-upto'
        $star.addClass 'star-set-after'

    if vote == FAVORITE
      add.hide()
      rm.show()
    else
      add.show()
      rm.hide()
    @post_score.text targetScore


  initShortcut: =>
    mapping =
      '`': REMOVE
      '1': GOOD
      '2': GREAT
      '3': FAVORITE

    for own key, value of mapping
      do (key, value) =>
        Mousetrap.bind key, => @set value


  setMouseover: (targetStar) =>
    if targetStar? && !targetStar.classList.contains('star')
      targetStar = $(targetStar).closest('.star')[0]

    if !targetStar?
      @mouseout()
      return

    targetScore = getScore(targetStar)

    for star in @stars
      score = getScore(star)
      $star = $(star)

      if score <= targetScore
        $star.removeClass 'star-hovered-after'
        $star.addClass 'star-hovered-upto'
      else
        $star.removeClass 'star-hovered-upto'
        $star.addClass 'star-hovered-after'
      if score != targetScore
        $star.removeClass 'star-hovered'
        $star.addClass 'star-unhovered'
      else
        $star.removeClass 'star-unhovered'
        $star.removeClass 'star-hovered'

    @desc.text @label[targetScore]


  mouseout: =>
    for star in @stars
      star.classList.remove 'star-hovered', 'star-unhovered', 'star-hovered-after', 'star-hovered-upto'

    @desc.text ''


  activateItem: (targetStar) =>
    return unless targetStar?

    if !targetStar.classList.contains('star')
      targetStar = $(targetStar).closest('.star')[0]

    return unless targetStar?

    score = getScore(targetStar)
    @set score

    score
