/* globals jQuery */
const $ = jQuery;

export function setTimeago (el, date) {
  $(el).timeago('update', date);
  setTitle(el, date);
}

function setTitle (el, date) {
  el.title = date.toString();
}

export default class Timeago {
  constructor () {
    this.observe();
    this.run();
  }

  run (nodes = document.body) {
    const $elements = $(nodes).find('.js-timeago').addBack('.js-timeago').timeago();

    for (const el of $elements) {
      setTitle(el, new Date(el.getAttribute('datetime')));
    }
  }

  observe () {
    this.observer = new window.MutationObserver(this.onMutate);

    this.observer.observe(document, {
      childList: true,
      subtree: true
    });
  }

  onMutate = (mutations) => {
    for (const mutation of mutations) {
      this.run(mutation.addedNodes);
    }
  };
}
