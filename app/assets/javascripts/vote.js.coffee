class Vote
    constructor: ->
        @api = {
            vote_url: "/post/vote.json"
        }
        @v = {
            fav: 3,
            great: 2,
            good: 1,
            remove: 0
        }
        @label = [
            "Remove Vote",
            "Good",
            "Great",
            "Favorite"
        ]

    get: ->
        if not @current_post
            @current_post = Moebooru.get('post').current
        try
            return @current_post.score
        catch err
            return null

    set: (score) ->
        return false if score > @v.fav
        Moebooru.request @api.vote_url, {id: @current_post.id, score: score}

    updateWidget: ->
        score = @get()
        i = 1
        while i <= @v.fav
            star = jQuery '.star-'+i
            if i <= score
                star.removeClass 'star-set-after'
                star.addClass 'star-set-upto'
            else
                star.removeClass 'star-set-upto'
                star.addClass 'star-set-after'
            i++
        false


jQuery ($) ->
    container = $ '#stats'
    return false if container.length == 0
    vote = new Vote()

    get_score = (o) ->
        match = o.match /star\-(\d)/
        try
            if match.length == 2
                return parseInt(match[1])
        catch err
        return -1

    $(".star").on 'click', ->
        score = get_score this.className
        vote.set score

    Moe.on vote.api.vote_url + ':ready', (e, [data]) ->
        Moebooru.addData data
        vote.updateWidget()

    Moe.on 'vote:update_widget', ->
        vote.updateWidget()
    
    $('.star').on 'mouseover', ->
        score = get_score this.className
        i=1
        while i <= vote.v.fav
            star = $ '.star-'+i
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
                star.addClass 'star-hovered'
            i++
        false

