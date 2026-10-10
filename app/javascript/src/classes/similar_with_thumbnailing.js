/* globals jQuery, notice */
import ThumbnailUserImage from './thumbnail_user_image';

const $ = jQuery;

export default class SimilarWithThumbnailing {
  constructor (form) {
    this._similar = null;
    this._form = form;
    this._forceFile = null;
    $(this._form).on('submit', this._onSubmit);
  }

  // Submit a post/similar request using the image currently in the canvas.
  _complete = (result) => {
    if (result.chromeFailure) {
      notice('The image failed to load; submitting normally...');
      this._forceFile = this._file;
      // Resend the submit event.  Defer it, so the notice can take effect before we
      // navigate off the page.
      window.setTimeout(() => {
        $(this._form).submit();
      });
      return;
    }
    if (!result.success) {
      if (!result.aborted) {
        window.alert("The file couldn't be loaded.");
      }
      return;
    }
    // Grab a data URL from the canvas; this is what we'll send to the server.
    $.ajax('/post/similar.json', {
      method: 'POST',
      data: {
        url: result.canvas.toDataURL()
      },
      dataType: 'json'
    }).done((resp) => {
      // Redirect to the search results.
      window.location.href = `/post/similar?search_id=${resp.search_id}`;
    }).fail((xhr) => {
      notice(`Error: ${xhr.responseJSON?.reason ?? 'unknown error'}`);
    });
  };

  _onSubmit = (e) => {
    const postFile = this._form.querySelector('#file');
    if ((postFile.files == null) || postFile.files.length === 0) {
      return;
    }
    // If we failed to load the image last time due to a silent Chrome error, continue with
    // the submission normally this time.
    const file = postFile.files[0];
    if ((this._forceFile != null) && this._forceFile === file) {
      this._forceFile = null;
      return;
    }
    e.preventDefault();
    this._similar?.destroy();
    this._similar = new ThumbnailUserImage(file, this._complete);
  };
}
