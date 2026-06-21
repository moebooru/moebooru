$ = jQuery

export default class Timeago
  @set: (el, date) =>
    $(el).timeago('update', date)
    @setTitle el, date


  @setTitle: (el, date) ->
    el.title = date.toString()


  constructor: ->
    @observe()
    @run()


  run: (nodes = document.body) =>
    $(nodes)
      .find(".js-timeago")
      .addBack(".js-timeago")
      .timeago()
      .each (_i, el) =>
        @constructor.setTitle el, new Date(el.getAttribute('datetime'))


  observe: =>
    @observer = new MutationObserver @onMutate

    config =
      childList: true
      subtree: true

    @observer.observe document, config


  onMutate: (mutations) =>
    for mutation in mutations
      @run mutation.addedNodes
