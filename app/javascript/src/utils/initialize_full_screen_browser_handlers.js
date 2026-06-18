import EmulateDoubleClick from 'src/classes/emulate_double_click';
import ResponsiveSingleClick from 'src/classes/responsive_single_click';
import { maintainUrlHash } from './maintain_url_hash';

/**
 * This file implements several helpers for fixing up full-page web apps on touchscreen
 * browsers:
 *
 * EmulateDoubleClick
 * ResponsiveSingleClick
 *
 * Most of these are annoying hacks to work around the fact that WebKit on browsers was
 * designed with displaying scrolling webpages in mind, apparently without consideration
 * for full-screen applications: pages that should fill the screen at all times.  Most
 * of the browser mobile hacks no longer make sense: separate display viewports, touch
 * dragging, double-click zooming and their associated side-effects.
 */
export function initializeFullScreenBrowserHandlers () {
  const userAgent = navigator.userAgent;
  // These handlers deal with heavily browser-specific issues.  Only install them
  // on browsers that have been tested to need them.
  if (userAgent.indexOf('Android') !== -1 && userAgent.indexOf('WebKit') !== -1) {
    new ResponsiveSingleClick(); // eslint-disable-line no-new
    new EmulateDoubleClick(); // eslint-disable-line no-new
  } else if ((userAgent.indexOf('iPhone') !== -1 || userAgent.indexOf('iPad') !== -1 || userAgent.indexOf('iPod') !== -1) && userAgent.indexOf('WebKit') !== -1) {
    new ResponsiveSingleClick(); // eslint-disable-line no-new
    new EmulateDoubleClick(); // eslint-disable-line no-new

    // In web app mode only:
    if (window.navigator.standalone) {
      maintainUrlHash();
    }
  }
}
