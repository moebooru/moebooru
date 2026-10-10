/* globals jQuery, Post */
import PreloadContainer from './preload_container';

const $ = jQuery;

/**
 * Parse `.js-preload-posts` and preload the specified non-blacklisted posts
 * The JSON should be an array of object `{ id, url }`.
 */
export default class PreloadPosts {
  urls = new Set();

  constructor () {
    $(this.exec);
  }

  exec = () => {
    this.getUrlsFromDocument();
    if (this.urls.size === 0) {
      return;
    }
    const container = new PreloadContainer();
    this.urls.forEach((url) => {
      container.preload(url);
    });
    this.urls.clear();
  };

  getUrlsFromDocument () {
    for (const postsJson of document.querySelectorAll('.js-preload-posts')) {
      this.getUrlsFromJson(JSON.parse(postsJson.text));
      postsJson.remove();
    }
  }

  getUrlsFromJson (json) {
    for (const post of json) {
      if (!Post.is_blacklisted(post.id)) {
        this.urls.add(post.url);
      }
    }
  }
}
