/* globals jQuery, User */
import ThumbnailUserImage from './thumbnail_user_image';

import { hideEl, showEl } from 'src/utils/dom';

// When file_field is changed to an image, run an image search and put a summary in
// results.
export default class UploadSimilarSearch {
  constructor (fileField, results) {
    this.file_field = fileField;
    this.results = results;
    this.file_field.addEventListener('change', this.field_changed_event);
  }

  field_changed_event = (event) => {
    if (this.file_field.files == null || this.file_field.files.length === 0) {
      hideEl(this.results);
      return;
    }
    this.results.innerHTML = 'Searching...';
    showEl(this.results);
    const file = this.file_field.files[0];
    new ThumbnailUserImage(file, this.thumbnail_complete); // eslint-disable-line no-new
  };

  thumbnail_complete = (result) => {
    if (!result.success) {
      this.results.innerHTML = 'Image load failed.';
      return;
    }

    return jQuery.ajax('/post/similar.json', {
      data: { url: result.canvas.toDataURL() },
      dataType: 'json',
      method: 'POST'
    }).done((json) => {
      let message;
      if (json.posts.length > 0) {
        const shownPosts = 3;
        const makeUrl = User.get_use_browser()
          ? (post) => `/post/browse#${post.id}`
          : (post) => `/post/show/${post.id}`;
        const posts = json.posts.slice(0, shownPosts).map((post) => (
          `<a href='${makeUrl(post)}'>post #${post.id}</a>`
        ));
        const seeAll = `<a href='/post/similar?search_id=${json.search_id}'>(see all)</a>`;
        let html = `Similar posts ${seeAll}: ${posts.join(', ')}`;
        if (json.posts.length > shownPosts) {
          const remainingPosts = json.posts.length - shownPosts;
          html += ` (${remainingPosts} more)`;
        }
        message = html;
      } else {
        message = 'No similar posts found.';
      }
      this.results.innerHTML = message;
    }).fail((xhr) => {
      this.results.innerHTML = xhr.responseJSON?.reason ?? 'unknown error';
    });
  };
}
