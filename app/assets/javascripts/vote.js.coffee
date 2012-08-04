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

    registerVotes: (votes) ->
        @posts = votes

    registerUserVotes: (votes) ->
        @votes = votes

    getScore: ->
        @current_post = Moebooru.get('post').current
        try
            return @current_post.score
        catch err
            return null

    getVote: ->
        @posts[@current_post.id]

    set: (vote) ->
        return false if vote > @v.fav
        Moebooru.request @api.vote_url, {id: @current_post.id, score: vote}

    updateWidget: ->
        score = @getScore()
        vote = @getVote()
        i = 1
        while i <= @v.fav
            star = jQuery '.star-'+i
            if i <= vote
                star.removeClass 'star-set-after'
                star.addClass 'star-set-upto'
            else
                star.removeClass 'star-set-upto'
                star.addClass 'star-set-after'
            i++
        jQuery('#post-score-'+@current_post.id).html score
        if @votes
            jQuery('#favorited-by').html Favorite.link_to_users @votes["3"]
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

    Moe.on 'vote:add', (e, data) ->
        vote.registerVotes data

    Moe.on 'vote:add_user_list', (e, data) ->
        vote.registerUserVotes data

    Moe.on vote.api.vote_url + ':ready', (e, data) ->
        Moebooru.addData data
        vote.updateWidget()

    Moe.on 'vote:update_widget', ->
        vote.updateWidget()
    
    $(".star-off").on 'click', ->
        score = get_score @className
        vote.set score
        false

    $('.star-off').on 'mouseover', ->
        score = get_score @className
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
        $('.vote-desc').html vote.label[score]
        false

    $('.star-off').on 'mouseout', ->
        i = 1
        while i <= vote.v.fav
            star = $ '.star-'+i
            star.removeClass 'star-hovered'
            star.removeClass 'star-unhovered'
            star.removeClass 'star-hovered-after'
            star.removeClass 'star-hovered-upto'
            i++
        $('.vote-desc').html ''
        false

