/* global Moebooru, jQuery */
import { Cookies } from 'src/cookie';

const $ = jQuery;

export default class RelatedTags {
  constructor () {
    $(this.initialize);
  }

  recentTags = () => {
    return this.parseTags(Cookies.get('recent_tags'));
  };

  myTags = () => {
    return this.parseTags(Cookies.get('my_tags'));
  };

  artistSource () {
    return $('#post_source').val();
  }

  source () {
    return $('#post_tags');
  }

  target () {
    return $('#related');
  }

  tagUrl (tag) {
    return Moebooru.path(`/post?tags=${encodeURIComponent(tag)}`);
  }

  initialize = () => {
    if (!(this.source().length && this.target().length)) {
      return;
    }
    $("[data-toggle='related-tags']").on('click', this.run);
    this.target().on('click', 'a', this.toggleTag);
    this.source().on('input keyup', this.highlightList);
    const $autoload = $('.js-related-tags--autoload');
    if ($autoload.length) {
      $autoload.click();
    } else {
      this.refreshList();
    }
  };

  parseTags = (tagsString) => {
    return (tagsString ?? '').match(/\S+/g) || [];
  };

  getTags = () => {
    const source = this.source();
    const selectFrom = source[0].selectionStart;
    const selectTo = source[0].selectionEnd;
    let tags = source.val();
    if (tags.length !== 0 && selectFrom !== 0 && selectFrom !== tags.length) {
      let selectionStart = tags.slice(0, selectFrom).lastIndexOf(' ');
      let selectionEnd = tags.indexOf(' ', selectTo);
      if (selectionStart === -1) {
        selectionStart = 0;
      }
      if (selectionEnd === -1) {
        selectionEnd = undefined;
      }
      tags = tags.slice(selectionStart, selectionEnd);
    }
    return tags;
  };

  refreshList = (extra) => {
    const buf = this.target().empty();
    if (this.myTags().length) {
      buf.append(this.buildList('My Tags', this.myTags()));
    }
    if (this.recentTags().length) {
      buf.append(this.buildList('Recent Tags', this.recentTags()));
    }
    for (const [title, tags] of Object.entries(extra ?? {})) {
      if (tags.length > 0) {
        buf.append(this.buildList(title, tags));
      }
    }
    this.highlightList();
  };

  highlightList = () => {
    const highlightedTags = {};
    for (const t of this.parseTags(this.source().val())) {
      highlightedTags[t] = true;
    }

    for (const tagLink of document.querySelectorAll('.js-related_tags--tag_link')) {
      if (highlightedTags[tagLink.dataset.tag] != null) {
        tagLink.classList.add('highlighted');
      } else {
        tagLink.classList.remove('highlighted');
      }
    }
  };

  buildList = (title, tags) => {
    const buf = $('<div>').addClass('tag-column');
    buf.append($('<h6>').text(title.replace(/_/g, ' ')));
    const tagsList = $('<ul>');

    for (const tag of tags.sort()) {
      const tagName = tag.replace(/_/g, ' ');
      const $tagLink = $('<a>')
        .text(tagName)
        .attr({ href: this.tagUrl(tag) })
        .attr('data-tag', tag)
        .addClass('js-related_tags--tag_link');
      tagsList.append($('<li>').append($tagLink));
    }

    return buf.append(tagsList);
  };

  fetchStart = () => {
    return this.target().html($('<em>').text('Fetching...'));
  };

  fetchArtistSuccess = (data) => {
    this.refreshList({ Artist: data.map((artist) => artist.name) });
  };

  fetchSuccess = (data) => {
    const tagsCollection = {};
    for (const [name, tags] of Object.entries(data)) {
      tagsCollection[name] = tags.map((tag) => tag[0]);
    }

    this.refreshList(tagsCollection);
  };

  toggleTag = (e) => {
    e.preventDefault();
    const tagName = $(e.target).text().replace(/\s/g, '_');
    const source = this.source();
    const currentTags = source.val();
    const jumpToEnd = source[0].selectionStart === currentTags.length;
    let newVal = $(e.target).hasClass('highlighted')
      ? currentTags.replace(tagName, '')
      : `${currentTags} ${tagName}`;
    newVal = `${newVal.trim().replace(/\s+/g, ' ')} `;
    if (newVal === ' ') {
      newVal = '';
    }
    source.val(newVal);
    if (jumpToEnd) {
      source[0].selectionStart = newVal.length;
    }
    this.highlightList();
    source.focus();
  };

  run = (e) => {
    e.preventDefault();
    const tags = this.getTags();
    let type = $(e.target).data('type');

    let data;
    let doneCallback;
    let url;

    if (type === 'artist-url') {
      const source = this.artistSource() || '';
      if (!(source.length && source.match(/^https?:\/\//))) {
        return;
      }
      url = Moebooru.path('/artist.json');
      data = {
        url: source,
        limit: 10
      };
      doneCallback = this.fetchArtistSuccess;
    } else {
      if (!tags.length) {
        return;
      }
      if (type === 'all') {
        type = null;
      }
      url = Moebooru.path('/tag/related.json');
      data = { type, tags };
      doneCallback = this.fetchSuccess;
    }

    this.fetchStart();
    $.ajax(url, { data }).done(doneCallback);
  };
}
