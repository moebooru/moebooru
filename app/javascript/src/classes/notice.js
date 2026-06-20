/* globals jQuery */
import { Cookies } from 'src/cookie';

const $ = jQuery;

export default class Notice {
  constructor () {
    $(this.initialize);
  }

  hide () {
    $('#notice-container').hide();
  }

  initialize = () => {
    const msg = Cookies.get('notice');

    if (msg == null || msg === '') return;

    this.show(msg, true);
    Cookies.remove('notice');
  };

  // If initial is true, this is a notice set by the notice cookie and not a
  // realtime notice from user interaction.
  show = (msg, initial) => {
    // If this is an initial notice, and this screen has a dedicated notice
    // container other than the floating notice, use that and don't hide it.
    if (initial ?? false) {
      const $staticNotice = $('#static_notice');
      if ($staticNotice.length > 0) {
        $staticNotice.text(msg).show();
        return;
      }
    }

    $('#notice').text(msg);
    $('#notice-container').show();

    clearTimeout(this.timeout);
    this.timeout = setTimeout(this.hide, 5000);
  };
}
