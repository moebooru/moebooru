#= require moebooru
#= require utils/fixed-encode-uri-component

jQuery(document).ready ($) ->
  window.Moebooru.relatedTags =
    recentTags: -> ($.cookie("recent_tags") || "").match(/\S+/g) || []
    myTags: -> ($.cookie("my_tags") || "").match(/\S+/g) || []
    artistSource: -> $("#post_source").val()
    source: -> $ "#post_tags"
    target: -> $ "#related"
    tagUrl: (tag) -> Moebooru.path "/post?tags=#{fixedEncodeURIComponent(tag)}"

    getTags: ->
      source = @source()
      selectFrom = source[0].selectionStart
      selectTo = source[0].selectionEnd
      tags = source.val()

      if tags.length != 0 && selectFrom != 0 && selectFrom != tags.length
        selectionStart = tags.slice(0, selectFrom).lastIndexOf " "
        selectionEnd = tags.indexOf " ", selectTo
        selectionStart = 0 if selectionStart == -1
        selectionEnd = undefined if selectionEnd == -1
        tags = tags.slice selectionStart, selectionEnd
      tags

    refreshList: (extra) ->
      buf = @target().empty()
      if @myTags().length > 0
        buf.append @buildList("My Tags", @myTags())
      if @recentTags().length > 0
        buf.append @buildList("Recent Tags", @recentTags())

      for title, tags of extra
        buf.append @buildList(title, tags) if tags.length > 0

      @highlightList()

    highlightList: ->
      highlightedTags = @source().val().match(/\S+/g) || []
      $(".tag-column").find("a").removeClass "highlighted"
      for tag in highlightedTags
        $(".tag-column").find("a[href='#{@tagUrl tag}']").addClass "highlighted"

    buildList: (title, tags) ->
      buf = $("<div>").addClass "tag-column"
      buf.append $("<h6>").text(title.replace /_/g, " ")
      tagsList = $("<ul>")

      for tag in tags.sort()
        tagName = tag.replace /_/g, " "
        tag = tag
        tagsList.append(
          $("<li>").append $("<a>").text(tagName).attr(href: @tagUrl(tag))
        )

      buf.append tagsList

    fetchStart: -> @target().html $("<em>").text("Fetching...")

    fetchArtistSuccess: (data) ->
      console.log (artist.name for artist in data)
      @refreshList "Artist": (artist.name for artist in data)

    fetchSuccess: (data) ->
      tagsCollection = {}
      for name, tags of data
        tagsCollection[name] = (tag[0] for tag in tags)
      @refreshList tagsCollection

    toggleTag: (e) ->
      e.preventDefault()
      tagName = $(e.target).text().replace /\s/g, "_"
      currentTags = @source().val()
      jumpToEnd = @source()[0].selectionStart == currentTags.length

      if $(e.target).hasClass "highlighted"
        newVal = currentTags.replace(tagName, "")
      else
        newVal = "#{currentTags} #{tagName}"

      newVal = "#{newVal.trim().replace(/\s\s+/g, " ")} "
      newVal = "" if newVal == " "

      @source().val(newVal)
      @source()[0].selectionStart = newVal.length if jumpToEnd
      @highlightList()
      @source().focus()

    run: (e) ->
      e.preventDefault()

      tags = @getTags()
      type = $(e.target).data("type")

      if type == "artist-url"
        source = @artistSource() || ""
        return unless source.length > 0 && source.match /^https?:\/\//
        @fetchStart()
        $.ajax
          url: Moebooru.path "/artist.json"
          data:
            url: source
            limit: 10
          success: $.proxy @fetchArtistSuccess, this
      else
        type = null if type == "all"
        return unless tags.length > 0
        @fetchStart()
        $.ajax
          url: Moebooru.path "/tag/related.json"
          data: { type: type, tags: tags }
          success: $.proxy @fetchSuccess, this

    initialize: ->
      return unless @source().length && @target().length
      $("[data-toggle='related-tags']").click $.proxy(@run, this)
      @target().on "click", "a", $.proxy(@toggleTag, this)
      @source().on "input keyup", $.proxy(@highlightList, this)
      if @artistSource()
        $("[data-toggle='related-tags'][data-type='artist-url']").click()
      else
        @refreshList()
