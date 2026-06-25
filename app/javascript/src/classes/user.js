/* globals jQuery, notice */
import { onKey } from 'src/utils/on_key';
import { Cookie } from 'src/cookie';

const $ = jQuery;

export default class User {
  constructor () {
    this.active_tab = null;
    this.checkXhr = null;
    this.current_state = null;
    this.pending_username = null;
    this.check_name_timer = null;
    this.last_username_in_form = null;
    this.success_func = null;
    this.messages = [];
  }

  cancel_check () {
    this.checkXhr?.abort();
  }

  reset_password (username, email, func) {
    return $.ajax('/user/reset_password.json', {
      data: {
        user: {
          name: username,
          email
        }
      },
      dataType: 'json',
      method: 'POST'
    }).done(func).fail((xhr) => {
      const json = xhr.responseJSON;
      if (json == null) {
        notice('Error: unknown error');
      } else {
        func(json);
      }
    });
  }

  check (username, password, background, func) {
    const parameters = { username };
    if (password) {
      parameters.password = password;
    }
    this.cancel_check();
    this.checkXhr = $.ajax('/user/check.json', {
      data: parameters,
      dataType: 'json',
      method: 'POST'
    }).done(func);
  }

  create (username, password, email, func) {
    const parameters = {
      user: {
        name: username,
        password
      }
    };
    if (email) {
      parameters.user.email = email;
    }
    $.ajax('/user/create.json', {
      data: parameters,
      dataType: 'json',
      method: 'POST'
    }).done(func);
  }

  init () {
    for (const noticeEl of document.querySelectorAll('#login-popup-notices span')) {
      this.messages.push(noticeEl.id);
    }
    // IE makes us jump lots of hoops.  We have to watch submit events on every object
    // instead of just window because IE doesn't support event capturing.  We have to
    // override the submit method in every form to catch programmatic submits, because
    // IE doesn't seem to support initiating events by firing them.

    // Also, since we can't capture events, we need to be sure our submit event is done
    // before other handlers, so if we cancel the event, we prevent other event handlers
    // from continuing.  However, we need to attach after forms have been created.  So,
    // this needs to be run as an early DOMLoaded event, and any other code that attaches
    // submit events to code needs to be run in a later DOMLoaded event (or later events).
    for (const form of document.querySelectorAll('form.need-signup')) {
      form.addEventListener('submit', this.run_login_onsubmit);
    }
    // If you select an item from the history dropdown in IE7, change events never fire, so
    // use keyup instead.  This isn't a problem with password fields, since there's no history
    // dropdown.
    document.getElementById('login-popup').addEventListener('submit', (e) => {
      e.stopPropagation();
      e.preventDefault();
      this.form_submitted();
    });
    document.getElementById('login-popup-submit').addEventListener('click', (e) => {
      e.stopPropagation();
      e.preventDefault();
      this.form_submitted();
    });
    document.getElementById('login-popup-cancel').addEventListener('click', (e) => {
      e.stopPropagation();
      e.preventDefault();
      this.close(false);
    });
    document.getElementById('login-popup-username').addEventListener('blur', (e) => {
      this.form_username_blur();
    });
    document.getElementById('login-popup-username').addEventListener('focus', (e) => {
      this.form_username_focus();
    });
    document.getElementById('login-popup-username').addEventListener('keyup', (e) => {
      this.form_username_changed(true);
    });
    for (const a of document.querySelectorAll('#login-tabs li')) {
      a.addEventListener('mousedown', (e) => {
        e.stopPropagation();
        e.preventDefault();
      });
      a.addEventListener('click', (e) => {
        e.stopPropagation();
        e.preventDefault();
        this.set_tab(a.id);
      });
    }
    // IE and FF are glitchy with form submission: they fail to submit forms unless
    // there's an <INPUT type="submit"> somewhere in the form.  IE is even worse:
    // even if there is one, if it's hidden on page load (including if it's a parent
    // element hidden), it'll never submit the form, even if it's shown later.  Don't
    // rely on this behavior; just catch enter presses and submit the form explicitly.
    onKey(13, {
      AllowInputFields: true,
      Element: document.getElementById('login-popup')
    }, (e) => {
      e.stop();
      this.form_submitted();
    });

    // Escape closes the login box.
    onKey(27, {
      AllowInputFields: true,
      AlwaysAllowOpera: true
    }, (e) => {
      if (!this.success_func) {
        return false;
      }
      this.close(false);
      return true;
    });
  }

  open (success) {
    if (this.success_func) {
      this.close(false);
    }
    this.success_func = success;
    document.getElementById('login-background').style.display = '';
    document.getElementById('login-container').style.display = '';
    this.set_tab('tab-login');
  }

  close (runSuccessFn) {
    if (!this.success_func) {
      return;
    }
    document.getElementById('login-background').style.display = 'none';
    document.getElementById('login-container').style.display = 'none';
    this.active_tab = null;
    this.check_name_timer = null;
    const func = this.success_func;
    this.success_func = null;
    if (runSuccessFn) {
      window.setTimeout(func, 0);
    }
  }

  run_login_onclick (event) {
    const target = event.target;
    const loggedIn = this.run_login(true, () => {
      target.click();
    });
    if (loggedIn) {
      return true;
    }
    // Login is running, so stop the event.  Don't just return false; call stop(), so
    // event.stopped is available to the caller if we've been sent this message via
    // Element.dispatchEvent.
    event.stopPropagation();
    event.preventDefault();
    return false;
  }

  run_login_onsubmit = (event) => {
    // Set skip_complete_on_true, so if we don't need to login, we don't resubmit the
    // event; we just don't cancel it.
    const target = event.target;
    const loggedIn = this.run_login(true, () => {
      target.requestSubmit();
    });
    if (loggedIn) {
      return true;
    }
    event.stopPropagation();
    event.preventDefault();
    return false;
  };

  run_login (onlyCompleteOnLogin, complete) {
    if (Cookie.get('user_info') !== '') {
      if (!onlyCompleteOnLogin) {
        complete();
      }
      return true;
    }
    this.open(complete);
    return false;
  }

  set_tab (tab) {
    if (this.active_tab === tab) {
      return;
    }
    this.active_tab = tab;
    this.check_name_timer = null;
    this.last_username_in_form = null;
    for (const li of document.querySelectorAll('#login-tabs li')) {
      li.classList.remove('selected');
    }
    document.getElementById(tab).classList.add('selected');

    for (const li of document.querySelectorAll('.tab-header-text')) {
      li.style.display = 'none';
    }
    document.getElementById(`${tab}-text`).style.display = '';

    const usernameInput = document.getElementById('login-popup-username');
    if (tab === 'tab-login') {
      // If the user's browser fills in a username but no password, focus the password.  Otherwise,
      // focus the username.
      const passwordInput = document.getElementById('login-popup-password');
      if (passwordInput.value === '' && usernameInput.value !== '') {
        passwordInput.focus();
      } else {
        usernameInput.focus();
      }
      this.set_state('login-blank');
    } else if (tab === 'tab-reset') {
      this.set_state('reset-blank');
      usernameInput.focus();
    }
    this.form_username_changed();
  }

  message (text) {
    for (const messageId of this.messages) {
      document.getElementById(messageId).style.display = 'none';
    }
    const messageEl = document.getElementById('login-popup-message');
    messageEl.innerHTML = text;
    messageEl.style.display = '';
  }

  set_state (state) {
    const show = {};
    if (state.match(/^login-/)) {
      show['login-popup-password-box'] = true;
      if (state === 'login-blank') {
        document.getElementById('login-popup-submit').innerText = 'Login';
      } else if (state === 'login-user-exists') {
        document.getElementById('login-popup-submit').innerText = 'Login';
      } else if (state === 'login-confirm-password') {
        show['login-popup-password-confirm-box'] = true;
        document.getElementById('login-popup-submit').innerText = 'Create account';
      } else if (state === 'login-confirm-password-mismatch') {
        document.getElementById('login-popup-submit').innerText = 'Create account';
      }
      show[`login-popup-${state}`] = true;
    } else if (state.match(/^reset-/)) {
      show['login-popup-email-box'] = true;
      document.getElementById('login-popup-submit').innerText = 'Reset password';
      show[`login-popup-${state}`] = true;
    }
    this.current_state = state;

    const all = ['login-popup-email-box', 'login-popup-password-box', 'login-popup-password-confirm-box', ...this.messages];
    for (const id of all) {
      document.getElementById(id).style.display = show[id] ? '' : 'none';
    }
  }

  form_username_changed (keyup) {
    const username = document.getElementById('login-popup-username').value;
    if (username === this.last_username_in_form) {
      return;
    }
    this.last_username_in_form = username;
    this.cancel_check();
    window.clearTimeout(this.check_name_timer);
    this.pending_username = null;
    if (username === '') {
      if (this.active_tab === 'tab-login') {
        this.set_state('login-blank');
      } else if (this.active_tab === 'tab-reset') {
        this.set_state('reset-blank');
      }
      return;
    }

    // Delay on keyup, so we don't send tons of requests.  Don't delay otherwise,
    // so we don't introduce lag when we don't have to.
    const ms = !keyup && this.check_name_timer
      ? 0
      : 500;

    // Make sure the UI is still usable if this never finished.  This way, we don't
    // lag the interface if these JSON requests are taking longer than usual; you should
    // be able to click "login" immediately as soon as a username and password are entered.
    // Entering a username and password and clicking "login" should still behave properly
    // if the username doesn't exist and the check_name_timer JSON request hasn't come
    // back yet.
    //
    // If the state isn't "blank", the button is already enabled.
    const checkName = () => {
      this.check_name_timer = null;
      this.check(username, null, true, (resp) => {
        if (resp.exists) {
          // Update the username to match the actual user's case.  If the form contents have
          // changed since we started this check, don't do this.  (We cancel this event if we
          // see the contents change, but the contents can change without this event firing
          // at all.)
          const usernameInput = document.getElementById('login-popup-username');
          const currentUsername = usernameInput.value;
          if (currentUsername === username) {
            if (!document.getElementById('login-popup').focused) {
              usernameInput.value = resp.name;
            } else {
              this.pending_username = resp.name;
            }
          }
        }
        if (this.active_tab === 'tab-login') {
          if (!resp.exists) {
            this.set_state('login-confirm-password');
          } else {
            this.set_state('login-user-exists');
          }
        } else if (this.active_tab === 'tab-reset') {
          if (!resp.exists) {
            this.set_state('reset-blank');
          } else if (resp.no_email) {
            this.set_state('reset-user-has-no-email');
          } else {
            this.set_state('reset-user-exists');
          }
        }
      });
    };
    this.check_name_timer = window.setTimeout(checkName, ms);
  }

  form_username_focus () {
    document.getElementById('login-popup').focused = true;
  }

  form_username_blur () {
    document.getElementById('login-popup').focused = false;
    // When the username field loses focus, update the username case to match the
    // result we got back from check(), if any.
    if (this.pending_username) {
      document.getElementById('login-popup').username.value = this.pending_username;
      this.pending_username = null;
    }
    // We watch keyup on the username, because change events are unreliable in IE; update
    // when focus is lost, too, so we see changes made without using the keyboard.
    this.form_username_changed(false);
  }

  form_submitted () {
    this.cancel_check();
    window.clearTimeout(this.check_name_timer);
    const username = document.getElementById('login-popup-username').value;
    const password = document.getElementById('login-popup-password').value;
    const passwordConfirm = document.getElementById('login-popup-password-confirm').value;
    const email = document.getElementById('login-popup-email').value;
    if (username === '') {
      return;
    }
    if (this.active_tab === 'tab-login') {
      if (password === '') {
        this.message('Please enter a password.');
        return;
      }
      if (this.current_state === 'login-confirm-password') {
        if (password !== passwordConfirm) {
          this.message("The passwords you've entered don't match.");
        } else {
          // create account
          this.create(username, password, null, (resp) => {
            if (resp.response === 'success') {
              this.close(true);
            } else if (resp.response === 'error') {
              this.message(resp.errors.join('<br>'));
            }
          });
        }
        return;
      }
      this.check(username, password, false, (resp) => {
        if (!resp.exists) {
          this.set_state('login-confirm-password');
          return;
        }
        if (resp.response === 'wrong-password') {
          notice('Incorrect password');
          return;
        }
        this.close(true);
      });
    } else if (this.active_tab === 'tab-reset') {
      if (email === '') {
        return;
      }
      this.reset_password(username, email, (resp) => {
        const stateMap = {
          success: 'reset-successful',
          'unknown-user': 'reset-unknown-user',
          'wrong-email': 'reset-user-email-incorrect',
          'no-email': 'reset-user-has-no-email',
          'invalid-email': 'reset-user-email-invalid'
        };

        const newState = stateMap[resp.result];
        if (newState != null) {
          this.set_state(newState);
        }
      });
    }
  }

  modify_blacklist (add, remove, success) {
    $.ajax('/user/modify_blacklist.json', {
      data: { add, remove },
      dataType: 'json',
      method: 'POST'
    }).done((resp) => {
      success?.(resp);
    }).fail((xhr) => {
      notice(`Error: ${xhr.responseJSON?.reason ?? 'unknown error'}`);
    });
  }

  set_pool_browse_mode (browseMode) {
    $.ajax('/user/update.json', {
      data: {
        user: {
          pool_browse_mode: browseMode
        }
      },
      dataType: 'json',
      method: 'POST'
    }).done((resp) => {
      window.location.reload();
    }).fail((xhr) => {
      notice(`Error: ${xhr.responseJSON?.reason ?? 'unknown error'}`);
    });
  }

  get_current_user_info () {
    const userInfo = Cookie.get('user_info');

    return userInfo
      ? userInfo.split(';')
      : null;
  }

  get_current_user_info_field (idx, def) {
    const userInfo = this.get_current_user_info();

    return userInfo?.[idx] ?? def;
  }

  get_current_user_id () {
    return parseInt(this.get_current_user_info_field(0, 0));
  }

  get_current_user_level () {
    return parseInt(this.get_current_user_info_field(1, 0));
  }

  get_use_browser () {
    return this.get_current_user_info_field(2, '0') === '1';
  }

  is_member_or_higher () {
    return this.get_current_user_level() >= 20;
  }

  is_mod_or_higher () {
    return this.get_current_user_level() >= 40;
  }
}
