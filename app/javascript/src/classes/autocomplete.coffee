import autocompleter from 'autocompleter'
import TagCompletion from './tag_completion'
import TagCompletionBox from './tag_completion_box'

$ = jQuery

autocompleterMap = (match) =>
  label: match
  value: match

export default class Autocomplete
  constructor: (@tagCompletionInstance) ->
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
    @tagCompletionInstance.observe_tag_changes_on_submit editForm, tags
