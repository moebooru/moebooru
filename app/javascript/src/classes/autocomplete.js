import autocompleter from 'autocompleter';
import TagCompletionBox from './tag_completion_box';

const $ = window.jQuery;

function autocompleterMap (match) {
  return {
    label: match,
    value: match
  };
}

export default class Autocomplete {
  constructor (tagCompletionInstance) {
    this.tagCompletionInstance = tagCompletionInstance;
    $(() => {
      this.genericCompletionAll();
      this.tagCompletion();
    });
  }

  genericCompletion (input) {
    const url = input.dataset.autocomplete;

    autocompleter({
      input,
      fetch: (text, update) => {
        $.ajax(url, {
          data: { term: text },
          dataType: 'json'
        }).done((matches) => {
          update(matches.map(autocompleterMap));
        });
      },
      onSelect: (match) => {
        input.value = match.value;
      },
      preventSubmit: 2 // OnSelect
    });
  }

  genericCompletionAll () {
    for (const input of document.querySelectorAll('[data-autocomplete]')) {
      this.genericCompletion(input);
    }
  }

  tagCompletion () {
    const editForm = document.querySelector('#edit-form');
    if (editForm == null) return;

    const tags = document.querySelector('.ac-tags');
    if (tags == null) return;

    new TagCompletionBox(tags); // eslint-disable-line no-new
    this.tagCompletionInstance.observe_tag_changes_on_submit(editForm, tags);
  }
}
