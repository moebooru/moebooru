var $, Autocomplete, autocompleterMap;

import autocompleter from 'autocompleter';

import TagCompletion from './tag_completion';

import TagCompletionBox from './tag_completion_box';

$ = jQuery;

autocompleterMap = (match) => {
  return {
    label: match,
    value: match
  };
};

export default Autocomplete = class Autocomplete {
  constructor(tagCompletionInstance) {
    this._genericCompletion = this._genericCompletion.bind(this);
    this._genericCompletionAll = this._genericCompletionAll.bind(this);
    this._tagCompletion = this._tagCompletion.bind(this);
    this.tagCompletionInstance = tagCompletionInstance;
    $(() => {
      this._genericCompletionAll();
      return this._tagCompletion();
    });
  }

  _genericCompletion(input) {
    var url;
    url = input.dataset.autocomplete;
    return autocompleter({
      input: input,
      fetch: (text, update) => {
        return $.ajax(url, {
          data: {
            term: text
          },
          dataType: 'json'
        }).done((matches) => {
          return update(matches.map(autocompleterMap));
        });
      },
      onSelect: (match) => {
        return input.value = match.value;
      },
      preventSubmit: 2 // OnSelect
    });
  }

  _genericCompletionAll() {
    var i, input, len, ref, results;
    ref = document.querySelectorAll('[data-autocomplete]');
    results = [];
    for (i = 0, len = ref.length; i < len; i++) {
      input = ref[i];
      results.push(this._genericCompletion(input));
    }
    return results;
  }

  _tagCompletion() {
    var editForm, tags;
    editForm = document.querySelector('#edit-form');
    if (editForm == null) {
      return;
    }
    tags = document.querySelector('.ac-tags');
    if (tags == null) {
      return;
    }
    new TagCompletionBox(tags);
    return this.tagCompletionInstance.observe_tag_changes_on_submit(editForm, tags);
  }

};
