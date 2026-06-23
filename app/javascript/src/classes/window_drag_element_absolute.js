import DragElement from 'src/classes/drag_element';
import { clamp } from 'src/utils/math';

// element should be positioned (eg. position: absolute).  When the element is dragged,
// scroll it around.
export default class WindowDragElementAbsolute {
  constructor (element, ondragCallback) {
    this.startdrag = this.startdrag.bind(this);
    this.ondrag = this.ondrag.bind(this);
    this.element = element;
    this.ondragCallback = ondragCallback;
    this.disabled = false;
    this.dragger = new DragElement(element, {
      ondrag: this.ondrag,
      onstartdrag: this.startdrag
    });
  }

  set_disabled (b) {
    this.disabled = b;
  }

  startdrag () {
    if (this.disabled) {
      return true;
    }
    // cancel
    this.scroll_anchor_x = this.element.offsetLeft;
    this.scroll_anchor_y = this.element.offsetTop;
    return false;
  }

  ondrag (e) {
    // Don't allow dragging the image off the screen; there'll be no way to
    // get it back.
    let minVisible = Math.min(100, this.element.offsetWidth);
    const scrollLeft = clamp(
      this.scroll_anchor_x + e.aX,
      minVisible - this.element.offsetWidth,
      window.innerWidth - minVisible
    );

    minVisible = Math.min(100, this.element.offsetHeight);
    const scrollTop = clamp(
      this.scroll_anchor_y + e.aY,
      minVisible - this.element.offsetHeight,
      window.innerHeight - minVisible
    );

    this.element.setStyle({
      left: `${scrollLeft}px`,
      top: `${scrollTop}px`
    });

    this.ondragCallback?.();
  }

  destroy () {
    this.dragger.destroy();
  }
}
