/* globals jQuery */
import { removeImageElement } from 'src/utils/image';

const $ = jQuery;

/**
 * file must be a Blob object.  Create and return a thumbnail of the image.
 * Perform an image search using post/similar.
 *
 * On completion, onComplete(result) will be called, where result is an object with
 * these properties:
 *
 * success: true or false.
 *
 * On failure:
 * aborted: true if failure was due to a user abort.
 * chromeFailure: If true, the image loaded but was empty.  Chrome probably ran out
 * of memory, but the selected file may be a valid image.
 *
 * On success:
 * canvas: On success, the canvas containing the thumbnailed image.
 */
export default class ThumbnailUserImage {
  constructor (file, onComplete) {
    this.file = file;
    this.canvas = document.createElement('canvas');
    this.image = document.createElement('img');
    this.onComplete = onComplete;
    this.url = URL.createObjectURL(this.file);
    $(this.image)
      .on('load', this.image_load_event)
      .on('abort', this.image_abort_event)
      .on('error', this.image_error_event);
    document.documentElement.addClassName('progress');
    this.image.src = this.url;
  }

  // Cancel any running request.  The onComplete callback will not be called.
  // The object must not be reused.
  destroy () {
    document.documentElement.removeClassName('progress');
    this.onComplete = null;
    $(this.image).off();
    this.image = removeImageElement(this.image);
    if (this.url != null) {
      URL.revokeObjectURL(this.url);
      this.url = null;
    }
  }

  completed (result) {
    this.onComplete?.(result);
    this.destroy();
  }

  // When the image finishes loading after form_submit_event sets it, update the canvas
  // thumbnail from it.
  image_load_event = (e) => {
    // Reduce the image size to thumbnail resolution.
    let width = this.image.width;
    let height = this.image.height;
    const maxWidth = 128;
    const maxHeight = 128;
    let ratio;
    if (width > maxWidth) {
      ratio = maxWidth / width;
      height *= ratio;
      width *= ratio;
    }
    if (height > maxHeight) {
      ratio = maxHeight / height;
      height *= ratio;
      width *= ratio;
    }
    width = Math.round(width);
    height = Math.round(height);
    // Set the canvas to the image size we want.
    const canvas = this.canvas;
    canvas.width = width;
    canvas.height = height;
    // Blit the image onto the canvas.
    const ctx = canvas.getContext('2d');
    // Clear the canvas, so check_image_contents can check that the data was correctly loaded.
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(this.image, 0, 0, canvas.width, canvas.height);
    if (!this.check_image_contents()) {
      this.completed({
        success: false,
        chromeFailure: true
      });
      return;
    }
    this.completed({
      success: true,
      canvas: this.canvas
    });
  };

  // Work around a Chrome bug.  When very large images fail to load, we still get
  // onload and the image acts like a loaded, completely transparent image, instead
  // of firing onerror.  This makes it difficult to tell if the image actually loaded
  // or not.  Check that the image loaded by looking at the results; reject the image
  // if it's completely transparent.
  check_image_contents () {
    const ctx = this.canvas.getContext('2d');
    const image = ctx.getImageData(0, 0, this.canvas.width, this.canvas.height);
    const data = image.data;
    // Iterate through the alpha components, and search for any nonzero value.
    let idx = 3;
    const maxIdx = image.width * image.height * 4;
    while (idx < maxIdx) {
      if (data[idx] !== 0) {
        return true;
      }
      idx += 4;
    }
    return false;
  }

  image_abort_event = (e) => {
    this.completed({
      success: false,
      aborted: true
    });
  };

  // This happens on normal errors, usually because the file isn't a supported image.
  image_error_event = (e) => {
    this.completed({
      success: false
    });
  };
}
