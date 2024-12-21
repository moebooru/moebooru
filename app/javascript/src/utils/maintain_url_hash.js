function updateStoredHash () {
  window.localStorage.setItem('current_hash', window.UrlHash.get_raw_hash());
}

/**
 * Save the URL hash to local DOM storage when it changes.  When called, restores the
 * previously saved hash.
 *
 * This is used on the iPhone only, and only when operating in web app mode (window.standalone).
 * The iPhone doesn't update the URL hash saved in the web app shortcut, nor does it
 * remember the current URL when using make-believe multitasking, which means every time
 * you switch out and back in you end up back to wherever you were when you first created
 * the web app shortcut.  Saving the URL hash allows switching out and back in without losing
 * your place.
 *
 * This should only be used in environments where it's been tested and makes sense.  If used
 * in a browser, or in a web app environment that properly tracks the URL hash, this will
 * just interfere with normal operation.
 */
export function maintainUrlHash () {
  // When any part of the URL hash changes, save it.
  window.UrlHash.observe(null, updateStoredHash);

  // Restore the previous hash, if any.
  const hash = window.localStorage.getItem('current_hash');
  if (hash != null) {
    window.UrlHash.set_raw_hash(hash);
  }
}
