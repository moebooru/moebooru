/* globals $, Element, notice, Post, UrlHash, Vars */
import DragElement from 'src/classes/drag_element';
import { sortArrayByDistance } from 'src/utils/array';
import { isTouchscreen } from 'src/utils/browser';
import PreloadContainer from './preload_container';

/**
 * Handle the thumbnail view, and navigation for the main view.
 *
 * Handle a large number (thousands) of entries cleanly.  Thumbnail nodes are created
 * as needed, and destroyed when they scroll off screen.  This gives us constant
 * startup time, loads thumbnails on demand, allows preloading thumbnails in advance
 * by creating more nodes in advance, and keeps memory usage constant.
 */
export default class ThumbnailView {
  constructor (container, view) {
    this.container = container;
    this.view = view;
    this.post_ids = [];
    this.post_frames = [];
    this.expanded_post_idx = null;
    this.centered_post_idx = null;
    this.centered_post_offset = 0;
    this.last_mouse_x = 0;
    this.last_mouse_y = 0;
    this.thumb_container_shown = true;
    this.allow_wrapping = true;
    this.thumb_preload_container = new PreloadContainer();
    this.unused_thumb_pool = [];
    // The [first, end) range of posts that are currently inside .post-browser-posts.
    this.posts_populated = [0, 0];
    document.on('DOMMouseScroll', this.document_mouse_wheel_event);
    document.on('mousewheel', this.document_mouse_wheel_event);
    document.on('viewer:displayed-image-loaded', this.displayed_image_loaded_event);
    document.on('viewer:set-active-post', (e) => {
      this.set_active_post(
        [e.memo.post_id, e.memo.post_frame],
        e.memo.lazy,
        e.memo.center_thumbs
      );
    });
    document.on('viewer:show-next-post', (e) => {
      this.show_next_post(e.memo.prev);
    });
    document.on('viewer:scroll', (e) => {
      this.scroll(e.memo.left);
    });
    document.on('viewer:set-thumb-bar', (e) => {
      if (e.memo.toggle) {
        this.show_thumb_bar(!this.thumb_container_shown);
      } else {
        this.show_thumb_bar(e.memo.set);
      }
    });
    document.on('viewer:loaded-posts', this.loaded_posts_event);
    UrlHash.observe('post-id', this.hashchange_post_id);
    UrlHash.observe('post-frame', this.hashchange_post_id);
    new DragElement(this.container, { ondrag: this.container_ondrag }); // eslint-disable-line no-new
    Element.on(window, 'resize', this.window_resize_event);
    this.container.on('mousemove', this.container_mousemove_event);
    this.container.on('mouseover', this.container_mouseover_event);
    this.container.on('mouseout', this.container_mouseout_event);
    this.container.on('click', this.container_click_event);
    this.container.on('dblclick', '.post-thumb,.browser-thumb-hover-overlay', this.container_dblclick_event);
    // Prevent the default behavior of left-clicking on the expanded thumbnail overlay.  It's
    // handled by container_click_event.
    this.container.down('.browser-thumb-hover-overlay').on('click', (event) => {
      if (event.isLeftClick()) {
        event.preventDefault();
      }
    });
    // For Android browsers, we're set to 150 DPI, which (in theory) scales us to a consistent UI size
    // based on the screen DPI.  This means that we can determine the physical screen size from the
    // window resolution: 150x150 is 1"x1".  Set a thumbnail scale based on this.  On a 320x480 HVGA
    // phone screen the thumbnails are about 2x too big, so set thumb_scale to 0.5.

    // For iOS browsers, there's no way to set the viewport based on the DPI, so it's fixed at 1x.
    // (Note that on Retina screens the browser lies: even though we request 1x, it's actually at
    // 0.5x and our screen dimensions work as if we're on the lower-res iPhone screen.  We can mostly
    // ignore this.)  CSS inches aren't implemented (the DPI is fixed at 96), so that doesn't help us.
    // Fall back on special-casing individual iOS devices.
    this.config = {};
    if (navigator.userAgent.indexOf('iPad') !== -1) {
      this.config.thumb_scale = 1.0;
    } else if (navigator.userAgent.indexOf('iPhone') !== -1 || navigator.userAgent.indexOf('iPod') !== -1) {
      this.config.thumb_scale = 0.5;
    } else if (navigator.userAgent.indexOf('Android') !== -1) {
      // We may be in landscape or portrait; use out the narrower dimension.
      const width = Math.min(window.innerWidth, window.innerHeight);
      // Scale a 320-width screen to 0.5, up to 1.0 for a 640-width screen.  Remember
      // that this width is already scaled by the DPI of the screen due to target-densityDpi,
      // so these numbers aren't actually real pixels, and this scales based on the DPI
      // and size of the screen rather than the pixel count.
      this.config.thumb_scale = width / 640;
      console.debug('Unclamped thumb scale: ' + this.config.thumb_scale);
      // Clamp to [0.5,1.0].
      this.config.thumb_scale = Math.min(this.config.thumb_scale, 1.0);
      this.config.thumb_scale = Math.max(this.config.thumb_scale, 0.5);
      console.debug('startup, window size: ' + window.innerWidth + 'x' + window.innerHeight);
    } else {
      // Unknown device, or not a mobile device.
      this.config.thumb_scale = 1.0;
    }
    console.debug('Thumb scale: ' + this.config.thumb_scale);
    this.config_changed();
    // Send the initial viewer:thumb-bar-changed event.
    this.thumb_container_shown = false;
    this.show_thumb_bar(true);
  }

  window_resize_event = (e) => {
    if (e.stopped) {
      return;
    }
    if (this.thumb_container_shown) {
      this.center_on_post_for_scroll(this.centered_post_idx);
    }
  };

  // Show the given posts.  If extending is true, post_ids are meant to extend a previous
  // search; attempt to continue where we left off.
  loaded_posts_event = (event) => {
    let postIds = event.memo.post_ids;
    const oldPostIds = this.post_ids;
    const oldCenteredPostIdx = this.centered_post_idx;
    this.remove_all_posts();
    // Filter blacklisted posts.
    postIds = postIds.reject(Post.is_blacklisted);
    this.post_ids = [];
    this.post_frames = [];
    for (const postId of postIds) {
      const post = Post.posts.get(postId);
      const idxs = post.frames.length;
      if (idxs > 0) {
        for (let frameIdx = 0; frameIdx < idxs; frameIdx++) {
          this.post_ids.push(postId);
          this.post_frames.push(frameIdx);
        }
      } else {
        this.post_ids.push(postId);
        this.post_frames.push(-1);
      }
    }
    this.allow_wrapping = !event.memo.can_be_extended_further;
    // Show the results box or "no results".  Do this before updating the results box to make sure
    // the results box isn't hidden when we update, which will make offsetLeft values inside it zero
    // and break things.  If the reason we have no posts is because we didn't do a search at all,
    // don't show no-results.
    this.container.down('.post-browser-no-results').show((event.memo.tags != null) && this.post_ids.length === 0);
    this.container.down('.post-browser-posts').show(this.post_ids.length !== 0);
    if (event.memo.extending) {
      // We're extending a previous search with more posts.  The new post list we get may
      // not line up with the old one: the post we're focused on may no longer be in the
      // search, or may be at a different index.

      // Find a nearby post in the new results.  Start searching at the post we're already
      // centered on.  If that doesn't match, move outwards from there.  Only look forward
      // a little bit, or we may match a post that was never seen and jump forward too far
      // in the results.
      const postIdSearchOrder = sortArrayByDistance(oldPostIds.slice(0, oldCenteredPostIdx + 3), oldCenteredPostIdx);
      let initialPostId = null;
      for (const postIdToSearch of postIdSearchOrder) {
        const post = Post.posts.get(postIdToSearch);
        if (post != null) {
          initialPostId = post.id;
          break;
        }
      }
      console.debug('center-on-' + initialPostId);
      if (initialPostId == null) {
        this.centered_post_offset = 0;
        initialPostId = postIds[0];
      }
      const centerOnPostIdx = this.post_ids.indexOf(initialPostId);
      this.center_on_post_for_scroll(centerOnPostIdx);
    } else {
      // A new search has completed.

      // resultsMode can be one of the following:

      // "center-on-first"
      // Don't change the active post.  Center the results on the first result.  This is used
      // when performing a search by clicking on a tag, where we don't want to center on the
      // post we're on (since it'll put us at some random spot in the results when the user
      // probably wants to browse from the beginning), and we don't want to change the displayed
      // post either.

      // "center-on-current"
      // Don't change the active post.  Center the results on the existing current item,
      // if possible.  This is used when we want to show a new search without disrupting the
      // shown post, such as the "child posts" link in post info, and when loading the initial
      // URL hash when we start up.

      // "jump-to-first"
      // Set the active post to the first result, and center on it.  This is used after making
      // a search in the tags box.
      const resultsMode = event.memo.load_options.results_mode || 'center-on-current';
      const initialPostIdAndFrame = resultsMode === 'center-on-first' || resultsMode === 'jump-to-first'
        ? [this.post_ids[0], this.post_frames[0]]
        : this.get_current_post_id_and_frame();

      const centerOnPostIdx = this.get_post_idx(initialPostIdAndFrame) ?? 0;
      this.centered_post_offset = 0;
      this.center_on_post_for_scroll(centerOnPostIdx);
      // If no post is currently displayed and we just completed a search, set the current post.
      // This happens when first initializing; we wait for the first search to complete to retrieve
      // info about the post we're starting on, instead of making a separate query.
      if (resultsMode === 'jump-to-first' || (this.view.wanted_post_id == null)) {
        this.set_active_post(initialPostIdAndFrame, false, false, true);
      }
    }
    if (event.memo.tags == null) {
      // If tags is null then no search has been done, which means we're on a URL
      // with a post ID and no search, eg. "/post/browse#12345".  Hide the thumb
      // bar, so we'll just show the post.
      this.show_thumb_bar(false);
    }
  };

  container_ondrag = (e) => {
    this.centered_post_offset -= e.dX;
    this.center_on_post_for_scroll(this.centered_post_idx);
  };

  container_mouseover_event = (event) => {
    let li;
    li = $(event.target);
    if (!li.hasClassName('.post-thumb')) {
      li = li.up('.post-thumb');
    }
    if (li) {
      this.expand_post(li.post_idx);
    }
  };

  container_mouseout_event = (event) => {
    let target;
    // If the mouse is leaving the hover overlay, hide it.
    target = $(event.target);
    if (!target.hasClassName('.browser-thumb-hover-overlay')) {
      target = target.up('.browser-thumb-hover-overlay');
    }
    if (target) {
      this.expand_post(null);
    }
  };

  hashchange_post_id = () => {
    const postIdAndFrame = this.get_current_post_id_and_frame();
    if (postIdAndFrame[0] == null) {
      return;
    }
    // If we're already displaying this post, ignore the hashchange.  Don't center on the
    // post if this is just a side-effect of clicking a post, rather than the user actually
    // changing the hash.
    const [postId, postFrame] = postIdAndFrame;
    if (postId === this.view.displayed_post_id && postFrame === this.view.displayed_post_frame) {
      return;
    }
    //    debug("ignored-hashchange");
    const newPostIdx = this.get_post_idx(postIdAndFrame);
    this.centered_post_offset = 0;
    this.center_on_post_for_scroll(newPostIdx);
    this.set_active_post(postIdAndFrame, false, false, true);
  };

  // Search for the given post ID and frame in the current search results, and return its
  // index.  If the given post isn't in post_ids, return null.
  get_post_idx (postIdAndFrame) {
    const [postId, postFrame] = postIdAndFrame;
    const postIdx = this.post_ids.indexOf(postId);
    if (postIdx === -1) {
      return null;
    }
    if (postFrame === -1) {
      return postIdx;
    }
    // A post-frame is specified.  Search for a matching post-id and post-frame.  We assume
    // here that all frames for a post are grouped together in postIds.
    for (let postFrameIdx = postIdx; this.post_ids[postFrameIdx] === postId; postFrameIdx++) {
      if (this.post_frames[postFrameIdx] === postFrame) {
        return postFrameIdx;
      }
    }
    // We found a matching post, but not a matching frame.  Return the post.
    return postIdx;
  }

  // Return the post and frame that's currently being displayed in the main view, based
  // on the URL hash.  If no post is displayed and no search results are available,
  // return [null, null].
  get_current_post_id_and_frame () {
    let postId = UrlHash.get('post-id');

    if (postId == null) {
      return this.post_ids.length === 0
        ? [null, null]
        : [this.post_ids[0], this.post_frames[0]];
    }

    postId = parseInt(postId);
    const postFrame = UrlHash.get('post-frame') ?? this.view.get_default_post_frame(postId);

    return [postId, postFrame];
  }

  // Track the mouse cursor when it's within the container.
  container_mousemove_event = (e) => {
    const x = e.pointerX() - document.documentElement.scrollLeft;
    const y = e.pointerY() - document.documentElement.scrollTop;
    this.last_mouse_x = x;
    this.last_mouse_y = y;
  };

  document_mouse_wheel_event = (event) => {
    event.stop();
    let val;
    if (event.wheelDelta) {
      val = event.wheelDelta;
    } else if (event.detail) {
      val = -event.detail;
    }
    if (this.thumb_container_shown) {
      document.fire('viewer:scroll', {
        left: val >= 0
      });
    } else {
      document.fire('viewer:show-next-post', {
        prev: val >= 0
      });
    }
  };

  // Set the post that's shown in the view.  The thumbs will be centered on the post
  // if centerThumbs is true.  See BrowserView.prototype.set_post for an explanation
  // of noHashChange.
  set_active_post (postIdAndFrame, lazy, centerThumbs, noHashChange, replaceHistory) {
    if (postIdAndFrame[0] == null) {
      return;
    }
    this.view.set_post(postIdAndFrame[0], postIdAndFrame[1], lazy, noHashChange, replaceHistory);
    if (centerThumbs) {
      const postIdx = this.get_post_idx(postIdAndFrame);
      this.centered_post_offset = 0;
      this.center_on_post_for_scroll(postIdx);
    }
  }

  set_active_post_idx (postIdx, lazy, centerThumbs, noHashChange, replaceHistory) {
    if (postIdx == null) {
      return;
    }
    const postId = this.post_ids[postIdx];
    const postFrame = this.post_frames[postIdx];
    this.set_active_post([postId, postFrame], lazy, centerThumbs, noHashChange, replaceHistory);
  }

  show_next_post (prev) {
    if (this.post_ids.length === 0) {
      return;
    }
    const currentIdx = this.get_post_idx([this.view.wanted_post_id, this.view.wanted_post_frame]) ?? 0;
    let add = prev ? -1 : 1;
    if (this.post_frames[currentIdx] !== this.view.wanted_post_frame && add === 1) {
      // We didn't find an exact match for the frame we're displaying, which usually means
      // we viewed a post frame, and then the user changed the view to the main post, and
      // the main post isn't in the thumbnails.

      // It's strange to be on the main post, to hit pgdn, and to end up on the second frame
      // because the nearest match was the first frame.  Instead, we should end up on the first
      // frame.  To do that, just don't add anything to the index.
      console.debug('Snapped the display to the nearest frame');
      if (add === 1) {
        add = 0;
      }
    }
    let newIdx = currentIdx;
    newIdx += add;
    newIdx += this.post_ids.length;
    newIdx %= this.post_ids.length;
    const wrapped = (prev && newIdx > currentIdx) || (!prev && newIdx < currentIdx);
    if (wrapped) {
      if (!this.allow_wrapping) {
        return;
      }
      if (!this.thumb_container_shown && prev) {
        notice('Continued from the end');
      } else if (!this.thumb_container_shown && !prev) {
        notice('Starting over from the beginning');
      }
    }
    this.set_active_post_idx(newIdx, true, true, false, true);
  }

  // Scroll the thumbnail view left or right.  Don't change the displayed post.
  scroll (left) {
    if (!this.thumb_container_shown) {
      return;
    }
    let newIdx = this.centered_post_idx;
    // If we're not centered on the post, and we're moving towards the center,
    // don't jump past the post.
    if (this.centered_post_offset > 0 && left) {
      // do nothing
    } else if (this.centered_post_offset < 0 && !left) {
      // do nothing
    } else {
      newIdx += left ? -1 : 1;
    }
    // Snap to the nearest post.
    this.centered_post_offset = 0;
    // Wrap the new index.
    if (newIdx < 0) {
      if (!this.allow_wrapping) {
        newIdx = 0;
      } else {
        newIdx = this.post_ids.length - 1;
      }
    } else if (newIdx >= this.post_ids.length) {
      if (!this.allow_wrapping) {
        newIdx = this.post_ids.length - 1;
      } else {
        newIdx = 0;
      }
    }
    this.center_on_post_for_scroll(newIdx);
  }

  // Hide the hovered post, if any, call center_on_post(post_idx), then hover over the correct post again.
  center_on_post_for_scroll (postIdx) {
    if (this.thumb_container_shown) {
      this.expand_post(null);
    }
    this.center_on_post(postIdx);
    // Now that we've re-centered, we need to expand the correct image.  Usually, we can just
    // wait for the mouseover event to fire, since we hid the expanded thumb overlay and the
    // image underneith it is now under the mouse.  However, browsers are badly broken here.
    // Opera doesn't fire mouseover events when the element under the cursor is hidden.  FF
    // fires the mouseover on hide, but misses the mouseout when the new overlay is shown, so
    // the next time it's hidden mouseover events are lost.

    // Explicitly figure out which item we're hovering over and expand it.
    if (this.thumb_container_shown) {
      const element = $(document.elementFromPoint(this.last_mouse_x, this.last_mouse_y));
      if (element) {
        const li = element.up('.post-thumb');
        if (li) {
          this.expand_post(li.post_idx);
        }
      }
    }
  }

  remove_post (right) {
    if (this.posts_populated[0] === this.posts_populated[1]) {
      return false;
    }
    // none to remove
    let nodeToRemove;
    const node = this.container.down('.post-browser-posts');
    if (right) {
      --this.posts_populated[1];
      nodeToRemove = node.lastChild;
    } else {
      ++this.posts_populated[0];
      nodeToRemove = node.firstChild;
    }
    // Remove the thumbnail that's no longer visible, and put it in unused_thumb_pool
    // so we can reuse it later.  This won't grow out of control, since we'll always use
    // an item from the pool if available rather than creating a new one.
    const item = node.removeChild(nodeToRemove);
    this.unused_thumb_pool.push(item);
    return true;
  }

  remove_all_posts () {
    while (this.remove_post(true)) {
      // just continue
    }
  }

  // Add the next thumbnail to the left or right side.
  add_post_to_display (right) {
    const node = this.container.down('.post-browser-posts');
    if (right) {
      const postIdxToPopulate = this.posts_populated[1];
      if (postIdxToPopulate === this.post_ids.length) {
        return false;
      }
      ++this.posts_populated[1];
      const thumb = this.create_thumb(postIdxToPopulate);
      node.insertBefore(thumb, null);
    } else {
      if (this.posts_populated[0] === 0) {
        return false;
      }
      --this.posts_populated[0];
      const postIdxToPopulate = this.posts_populated[0];
      const thumb = this.create_thumb(postIdxToPopulate);
      node.insertBefore(thumb, node.firstChild);
    }
    return true;
  }

  // Fill the container so postIdx is visible.
  populate_post (postIdx) {
    if (this.is_post_idx_shown(postIdx)) {
      return;
    }
    // If postIdx is on the immediate border of what's already displayed, add it incrementally, and
    // we'll cull extra posts later.  Otherwise, clear all of the posts and populate from scratch.
    if (postIdx === this.posts_populated[1]) {
      this.add_post_to_display(true);
      return;
    } else if (postIdx === this.posts_populated[0]) {
      this.add_post_to_display(false);
      return;
    }
    // postIdx isn't on the boundary, so we're jumping posts rather than scrolling.
    // Clear the container and start over.
    this.remove_all_posts();
    const node = this.container.down('.post-browser-posts');
    const thumb = this.create_thumb(postIdx);
    node.appendChild(thumb);
    this.posts_populated[0] = postIdx;
    this.posts_populated[1] = postIdx + 1;
  }

  is_post_idx_shown (postIdx) {
    return postIdx >= this.posts_populated[1]
      ? false
      : postIdx >= this.posts_populated[0];
  }

  // Return the total width of all thumbs to the left or right of postIdx, not
  // including itself.
  get_width_adjacent_to_post (postIdx, right) {
    const post = $('p' + postIdx);
    if (right) {
      const rightmostNode = post.parentNode.lastChild;
      if (rightmostNode === post) {
        return 0;
      }
      const rightEdge = rightmostNode.offsetLeft + rightmostNode.offsetWidth;
      const centerPostRightEdge = post.offsetLeft + post.offsetWidth;
      return rightEdge - centerPostRightEdge;
    } else {
      return post.offsetLeft;
    }
  }

  // Center the thumbnail strip on postIdx.  If postId isn't in the display, do nothing.
  // Fire viewer:need-more-thumbs if we're scrolling near the edge of the list.
  center_on_post (postIdx) {
    if (!this.post_ids) {
      console.debug('unexpected: center_on_post has no post_ids');
      return;
    }
    const postId = this.post_ids[postIdx];
    if (Post.posts.get(postId) == null) {
      return;
    }
    if (postIdx > this.post_ids.length * 3 / 4) {
      (function () { // We're coming near the end of the loaded posts, so load more.  We may be currently
        // in the middle of setting up the post; defer this, so we finish what we're doing first.
        document.fire('viewer:need-more-thumbs', {
          view: this
        });
      }).defer();
    }
    this.centered_post_idx = postIdx;
    if (!this.thumb_container_shown) {
      return;
    }

    // If centered_post_offset is high enough to put the actual center post somewhere else,
    // adjust it towards zero and change centered_post_idx.  This keeps centered_post_idx
    // pointing at the item that's actually centered.
    const post = $('p' + this.centered_post_idx);
    if (post) {
      const pos = post.offsetWidth / 2 + this.centered_post_offset;
      if (!(pos >= 0 && pos < post.offsetWidth)) {
        const nextPostIdx = this.centered_post_idx + (this.centered_post_offset > 0 ? +1 : -1);
        const nextPost = $('p' + nextPostIdx);
        if (nextPost != null) {
          const currentPostCenter = post.offsetLeft + post.offsetWidth / 2;
          const nextPostCenter = nextPost.offsetLeft + nextPost.offsetWidth / 2;
          const distance = nextPostCenter - currentPostCenter;
          this.centered_post_offset -= distance;
          this.centered_post_idx = nextPostIdx;
          postIdx = this.centered_post_idx;
        }
      }
    }

    this.populate_post(postIdx);
    // Make sure that we have enough posts populated around the one we're centering
    // on to fill the display.  If we have too many nodes, remove some.
    for (const right of [false, true]) {
      // We need at least this.container.offsetWidth/2 in each direction.  Load a little more, to
      // reduce flicker.
      const minimumDistance = 1.25 * this.container.offsetWidth / 2;
      const maximumDistance = minimumDistance + 500;
      while (true) {
        // let added = false; // TODO: unchanged variable
        let width = this.get_width_adjacent_to_post(postIdx, right);
        // If we're offset to the right then we need more data to the left, and vice versa.
        width += this.centered_post_offset * (right ? -1 : 1);
        if (width < 0) {
          width = 1;
        }
        if (width < minimumDistance) {
          if (!this.add_post_to_display(right)) {
            break;
          }
        } else if (width > maximumDistance) {
          // We have a lot of posts off-screen.  Remove one.
          this.remove_post(right);
          // TODO: unreachable code
          // Sanity check: we should never add and remove in the same direction.  If this
          // happens, the distance between minimumDistance and maximumDistance may be less
          // than the width of a single thumbnail.
          // if (added) {
          //   window.alert('error');
          //   break;
          // }
        } else {
          break;
        }
      }
    }
    this.preload_thumbs();
    // We always center the thumb.  Don't clamp to the edge when we're near the first or last
    // item, so we always have empty space on the sides for expanded landscape thumbnails to
    // be visible.
    const thumb = $('p' + postIdx);
    const centerOnPosition = this.container.offsetWidth / 2;
    let shiftPixelsRight = centerOnPosition - (thumb.offsetWidth / 2) - thumb.offsetLeft;
    shiftPixelsRight -= this.centered_post_offset;
    shiftPixelsRight = Math.round(shiftPixelsRight);
    const node = this.container.down('.post-browser-scroller');
    node.setStyle({
      left: shiftPixelsRight + 'px'
    });
  }

  // Preload thumbs on the boundary of what's actually displayed.
  preload_thumbs () {
    const postIdxs = [];
    for (let i = 0; i < 5; i++) {
      let preloadPostIdx = this.posts_populated[0] - i - 1;
      if (preloadPostIdx >= 0) {
        postIdxs.push(preloadPostIdx);
      }
      preloadPostIdx = this.posts_populated[1] + i;
      if (preloadPostIdx < this.post_ids.length) {
        postIdxs.push(preloadPostIdx);
      }
    }
    // Remove any preloaded thumbs that are no longer in the preload list.
    for (const element of this.thumb_preload_container.getAll()) {
      const postIdx = element.post_idx;
      if (postIdxs.indexOf(postIdx) !== -1) {
        // The post is staying loaded.  Clear the value in postIdxs, so we don't load it
        // again down below.
        postIdxs[postIdx] = null;
        continue;
      }
      // The post is no longer being preloaded.  Remove the preload.
      this.thumb_preload_container.cancelPreload(element);
    }
    // Add new preloads.
    for (const postIdx of postIdxs) {
      if (postIdx == null) {
        continue;
      }
      const postId = this.post_ids[postIdx];
      const post = Post.posts.get(postId);
      const postFrame = this.post_frames[postIdx];
      const url = postFrame === -1
        ? post.preview_url
        : post.frames[postFrame].preview_url;
      const element = this.thumb_preload_container.preload(url);
      element.post_idx = postIdx;
    }
  }

  expand_post (postIdx) {
    // Thumbs on click for touchpads doesn't make much sense anyway--touching the thumb causes it
    // to be loaded.  It also triggers a bug in iPhone WebKit (covering up the original target of
    // a mouseover during the event seems to cause the subsequent click event to not be delivered).
    // Just disable hover thumbnails for touchscreens.
    if (isTouchscreen) {
      return;
    }
    if (!this.thumb_container_shown) {
      return;
    }
    const postId = this.post_ids[postIdx];
    const overlay = this.container.down('.browser-thumb-hover-overlay');
    overlay.hide();
    overlay.down('IMG').src = Vars.asset['blank.gif'];
    this.expanded_post_idx = postIdx;
    if (postIdx == null) {
      return;
    }
    const post = Post.posts.get(postId);
    if (post.status === 'deleted') {
      return;
    }
    const thumb = $('p' + postIdx);
    const bottom = this.container.down('.browser-bottom-bar').offsetHeight;
    overlay.style.bottom = bottom + 'px';
    const postFrame = this.post_frames[postIdx];
    let imageWidth;
    let imageUrl;
    if (postFrame !== -1) {
      const frame = post.frames[postFrame];
      imageWidth = frame.preview_width;
      imageUrl = frame.preview_url;
    } else {
      imageWidth = post.actual_preview_width;
      imageUrl = post.preview_url;
    }
    const left = thumb.cumulativeOffset().left - (imageWidth / 2) + thumb.offsetWidth / 2;
    overlay.style.left = left + 'px';
    // If the hover thumbnail overflows the right edge of the viewport, it'll extend the document and
    // allow scrolling to the right, which we don't want.  overflow: hidden doesn't fix this, since this
    // element is absolutely positioned.  Set the max-width to clip the right side of the thumbnail if
    // necessary.
    const maxWidth = document.viewport.getDimensions().width - left;
    overlay.style.maxWidth = maxWidth + 'px';
    overlay.href = '/post/browse#' + post.id + this.view.post_frame_hash(post, postFrame);
    overlay.down('IMG').src = imageUrl;
    overlay.show();
  }

  create_thumb (postIdx) {
    const postId = this.post_ids[postIdx];
    const postFrame = this.post_frames[postIdx];
    const post = Post.posts.get(postId);
    // Reuse thumbnail blocks that are no longer in use, to avoid WebKit memory leaks: it
    // doesn't like creating and deleting lots of images (or blocks with images inside them).

    // Thumbnails are hidden until they're loaded, so we don't show ugly load-borders.  This
    // also keeps us from showing old thumbnails before the new image is loaded.  Use visibility:
    // hidden, not display: none, or the size of the image won't be defined, which breaks
    // center_on_post.
    let item;
    if (this.unused_thumb_pool.length === 0) {
      const div = '<div class="inner">' + '<a class="thumb" tabindex="-1">' + '<img alt="" class="preview" onload="this.style.visibility = \'visible\';">' + '</a>' + '</div>';
      item = $(document.createElement('li'));
      item.innerHTML = div;
      item.className = 'post-thumb';
    } else {
      item = this.unused_thumb_pool.pop();
    }
    item.id = 'p' + postIdx;
    item.post_idx = postIdx;
    item.down('A').href = '/post/browse#' + post.id + this.view.post_frame_hash(post, postFrame);
    // If the image is already what we want, then leave it alone.  Setting it to what it's
    // already set to won't necessarily cause onload to be fired, so it'll never be set
    // back to visible.
    const img = item.down('IMG');
    const url = postFrame === -1
      ? post.preview_url
      : post.frames[postFrame].preview_url;

    if (img.src !== url) {
      img.style.visibility = 'hidden';
      img.src = url;
    }
    this.set_thumb_dimensions(item);
    return item;
  }

  set_thumb_dimensions = (li) => {
    const postIdx = li.post_idx;
    const postId = this.post_ids[postIdx];
    const postFrame = this.post_frames[postIdx];
    const post = Post.posts.get(postId);
    let width;
    let height;
    if (postFrame !== -1) {
      const frame = post.frames[postFrame];
      width = frame.preview_width;
      height = frame.preview_height;
    } else {
      width = post.actual_preview_width;
      height = post.actual_preview_height;
    }
    width *= this.config.thumb_scale;
    height *= this.config.thumb_scale;
    // This crops blocks that are too wide, but doesn't pad them if they're too
    // narrow, since that creates odd spacing.

    // If the height of this block is changed, adjust .post-browser-posts-container in
    // config_changed.
    const blockSize = [Math.min(width, 200 * this.config.thumb_scale), 200 * this.config.thumb_scale];
    const cropLeft = Math.round((width - blockSize[0]) / 2);
    const padTop = Math.max(0, blockSize[1] - height);
    const inner = li.down('.inner');
    inner.actual_width = blockSize[0];
    inner.actual_height = blockSize[1];
    inner.setStyle({
      width: blockSize[0] + 'px',
      height: blockSize[1] + 'px'
    });
    const img = inner.down('img');
    img.width = width;
    img.height = height;
    img.setStyle({
      marginTop: padTop + 'px',
      marginLeft: -cropLeft + 'px'
    });
  };

  config_changed () {
    // Adjust the size of the container to fit the thumbs at the current scale.  They're the
    // height of the thumb block, plus ten pixels for padding at the top and bottom.
    const containerHeight = 200 * this.config.thumb_scale + 10;
    this.container.down('.post-browser-posts-container').setStyle({
      height: containerHeight + 'px'
    });
    this.container.select('LI.post-thumb').each(this.set_thumb_dimensions);
    this.center_on_post_for_scroll(this.centered_post_idx);
  }

  // Handle clicks and doubleclicks on thumbnails.  These events are handled by
  // the container, so we don't need to put event handlers on every thumb.
  container_click_event = (event) => {
    // Ignore the click if it was stopped by the DragElement.
    if (event.stopped) {
      return;
    }
    if ($(event.target).up('.browser-thumb-hover-overlay')) {
      // The hover overlay was clicked.  When the user clicks a thumbnail, this is
      // usually what happens, since the hover overlay covers the actual thumbnail.
      this.set_active_post_idx(this.expanded_post_idx);
      event.preventDefault();
      return;
    }
    const li = $(event.target).up('.post-thumb');
    if (li == null) {
      return;
    }
    // An actual thumbnail was clicked.  This can happen if we don't have the expanded
    // thumbnails for some reason.
    event.preventDefault();
    this.set_active_post_idx(li.post_idx);
  };

  container_dblclick_event = (event) => {
    if (event.button) {
      return;
    }
    event.preventDefault();
    this.show_thumb_bar(false);
  };

  show_thumb_bar (shown) {
    if (this.thumb_container_shown === shown) {
      return;
    }
    this.thumb_container_shown = shown;
    this.container.show(shown);
    // If the centered post was changed while we were hidden, it wasn't applied by
    // center_on_post, so do it now.
    this.center_on_post_for_scroll(this.centered_post_idx);
    document.fire('viewer:thumb-bar-changed', {
      shown: this.thumb_container_shown,
      height: this.thumb_container_shown ? this.container.offsetHeight : 0
    });
  }

  // Return the next or previous post, wrapping around if necessary.
  get_adjacent_post_idx_wrapped (postIdx, next) {
    postIdx += next ? 1 : -1;

    return (postIdx + this.post_ids.length) % this.post_ids.length;
  }

  displayed_image_loaded_event = (event) => {
    if (this.post_ids == null) {
      return;
    }
    const postId = event.memo.post_id;
    const postFrame = event.memo.post_frame;
    const postIdx = this.get_post_idx([postId, postFrame]);
    if (postIdx == null) {
      return;
    }
    /**
     * The image in the post we're displaying is finished loading.
     *
     * Preload the next and previous posts.  Normally, one or the other of these will
     * already be in cache.
     *
     * Include the current post in the preloads, so if we switch from a frame back to
     * the main image, the frame itself will still be loaded.
     */
    const postIdsToPreload = [];
    postIdsToPreload.push([this.post_ids[postIdx], this.post_frames[postIdx]]);
    let adjacentPostIdx = this.get_adjacent_post_idx_wrapped(postIdx, true);
    if (adjacentPostIdx != null) {
      postIdsToPreload.push([this.post_ids[adjacentPostIdx], this.post_frames[adjacentPostIdx]]);
    }
    adjacentPostIdx = this.get_adjacent_post_idx_wrapped(postIdx, false);
    if (adjacentPostIdx != null) {
      postIdsToPreload.push([this.post_ids[adjacentPostIdx], this.post_frames[adjacentPostIdx]]);
    }
    this.view.preload(postIdsToPreload);
  };
}
