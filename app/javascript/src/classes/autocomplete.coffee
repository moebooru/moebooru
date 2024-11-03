import autocompleter from 'autocompleter'

$ = jQuery

autocompleterMap = (match) =>
  label: match
  value: match

export default class Autocomplete
  constructor: ->
    $ =>
      @_genericCompletionAll()
      @_tagCompletion()


  _genericCompletion: (input) =>
    url = input.dataset.autocomplete
    autocompleter
      input: input
      fetch: (text, update) =>
        $.ajax url,
          data:
            term: text
          dataType: 'json'
        .done (matches) =>
          update matches.map(autocompleterMap)
      onSelect: (match) => input.value = match.value
      preventSubmit: 2 # OnSelect


  _genericCompletionAll: =>
    for input in document.querySelectorAll('[data-autocomplete]')
      @_genericCompletion(input)


  _tagCompletion: =>
    editForm = document.querySelector('#edit-form')

    return if !editForm?

    tags = document.querySelector('.ac-tags')

    return if !tags?

    new TagCompletionBox(tags)
    TagCompletion?.observe_tag_changes_on_submit editForm, tags
