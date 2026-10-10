import { distanceSquared } from 'src/utils/math';

/**
 * Mobile WebKit has serious problems with the click event: it delays them for the
 * entire double-click timeout, and if a double-click happens it doesn't deliver the
 * click at all.  This makes clicks unresponsive, and it has this behavior even
 * when the page can't be zoomed, which means nothing happens at all.
 *
 * Generate click events from touchend events to bypass this mess.
 */
export default class ResponsiveSingleClick {
  constructor () {
    this.last_touch = null;
    window.addEventListener('touchstart', this.touchstart_event, false);
    window.addEventListener('touchend', this.touchend_event, false);
    // This is a capturing listener, so we can intercept clicks before they're
    // delivered to anyone.
    window.addEventListener('click', this.click_event, true);
  }

  touchstart_event = (event) => {
    // Watch out: in older versions of WebKit, the event.touches array and the items inside
    // it are actually modified in-place when the user drags.  That means that we can't just
    // save the entire array for comparing in touchend.
    // If we get a touch while we already have a touch, it's multitouch, which is never
    // a click, so cancel the click.
    if (this.last_touch != null) {
      console.debug('Cancelling click (multitouch)');
      this.last_touch = null;
      return;
    }
    const touch = event.changedTouches[0];
    this.last_touch = [touch.screenX, touch.screenY];
  };

  touchend_event = (event) => {
    const lastTouch = this.last_touch;
    if (lastTouch == null) {
      return;
    }
    this.last_touch = null;
    const touch = event.changedTouches[0];
    const thisTouch = [touch.screenX, touch.screenY];
    // Don't trigger a click if the point has moved too far.
    const distance = distanceSquared(thisTouch[0], thisTouch[1], lastTouch[0], lastTouch[1]);
    if (distance > 50) {
      return;
    }
    const e = document.createEvent('MouseEvent');
    e.initMouseEvent('click', true, true, window, 1, touch.screenX, touch.screenY, touch.clientX, touch.clientY, false, false, false, false, 0, null);
    e.synthesized_click = true;
    window.setTimeout(() => {
      // If we dispatch the click immediately, EmulateDoubleClick won't receive a
      // touchstart for the next click.  Defer dispatching it until we return.
      event.target.dispatchEvent(e);
    });
  };

  /**
   *  Capture and cancel all clicks except the ones we generate.
   */
  click_event = (event) => {
    if (!event.synthesized_click) {
      event.stop();
    }
  };
}
