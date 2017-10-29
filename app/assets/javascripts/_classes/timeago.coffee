@Moe ?= {}
$ = jQuery

class @Moe.Timeago
  constructor: ->
    @observer = new MutationObserver @onMutate
    config =
      childList: true
      subtree: true
    @observer.observe document, config


  onMutate: (mutations) =>
    for mutation in mutations
      $(mutation.addedNodes)
        .find(".js-timeago")
        .addBack(".js-timeago")
        .timeago()
        .each (_i, el) ->
          el.title = new Date(el.dateTime).toString()
        .removeClass(".js-timeago")
