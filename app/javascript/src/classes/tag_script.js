/* globals notice, Post */
import { Cookie } from 'src/cookie';

export default class TagScript {
  constructor () {
    this.TagEditArea = null;
  }

  load = () => {
    this.TagEditArea.value = Cookie.get('tag-script');
  };

  save = () => {
    Cookie.put('tag-script', this.TagEditArea.value);
  };

  init (element, x) {
    this.TagEditArea = element;
    this.load();
    this.TagEditArea.observe('change', this.save);
    this.TagEditArea.observe('focus', Post.reset_tag_script_applied);
    // This mostly keeps the tag script field in sync between windows, but it
    // doesn't work in Opera, which sends focus events before blur events.
    Event.on(window, 'unload', this.save);
    document.observe('focus', this.load);
  }

  parse (script) {
    return script.match(/\[.+?\]|\S+/g);
  }

  test (tags, predicate) {
    for (const x of predicate.match(/\S+/g)) {
      if (x[0] === '-') {
        if (tags.include(x.slice(1))) {
          return false;
        }
      } else {
        if (!tags.include(x)) {
          return false;
        }
      }
    }

    return true;
  }

  process (tags, command) {
    if (command.match(/^\[if/)) {
      const match = command.match(/\[if\s+(.+?)\s*,\s*(.+?)\]/);
      if (this.test(tags, match[1])) {
        return this.process(tags, match[2]);
      } else {
        return tags;
      }
    } else if (command === '[reset]') {
      return [];
    } else if (command[0] === '-' && command.indexOf('-pool:') !== 0) {
      return tags.reject(function (x) {
        return x === command.substr(1, 100);
      });
    } else {
      tags.push(command);
      return tags;
    }
  }

  run (postIds, tagScript, finished) {
    if (!Object.isArray(postIds)) {
      postIds = [postIds];
    }
    const commands = this.parse(tagScript) || [];
    const posts = [];
    for (const postId of postIds) {
      const post = Post.posts.get(postId);
      const oldTags = post.tags.join(' ');
      for (const x of commands) {
        post.tags = this.process(post.tags, x);
      }
      posts.push({
        id: postId,
        oldTags,
        tags: post.tags.join(' ')
      });
    }
    notice('Updating ' + posts.length + (postIds.length === 1 ? ' post' : ' posts'));
    Post.update_batch(posts, finished);
  }
}
