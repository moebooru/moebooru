/* globals Post */
// Update the window title when the display changes.
export default class WindowTitleHandler {
  constructor () {
    this.searched_tags = '';
    this.post_id = null;
    this.post_frame = null;
    this.pool = null;
    document.on('viewer:searched-tags-changed', (e) => {
      this.searched_tags = e.memo.tags ?? '';
      this.update();
    });
    document.on('viewer:displayed-post-changed', (e) => {
      this.post_id = e.memo.post_id;
      this.post_frame = e.memo.post_id;
      this.update();
    });
    document.on('viewer:displayed-pool-changed', (e) => {
      this.pool = e.memo.pool;
      this.update();
    });
    this.update();
  }

  update () {
    let title;
    if (this.pool) {
      const post = Post.posts.get(this.post_id);
      title = this.pool.name.replace(/_/g, ' ');
      if (post != null && post.pool_posts) {
        const poolPost = post.pool_posts[this.pool.id];
        if (poolPost) {
          const sequence = poolPost.sequence;
          title += ' ';
          if (sequence.match(/^[0-9]/)) {
            title += '#';
          }
          title += sequence;
        }
      }
    } else {
      title = `/${this.searched_tags.replace(/_/g, ' ')}`;
    }
    title += ' - Browse';
    document.title = title;
  }
}
