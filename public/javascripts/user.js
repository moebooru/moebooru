User = {
  disable_samples: function() {
    new Ajax.Request("/user/update.json", {
      parameters: {
        "user[show_samples]": false
      },

      onComplete: function(resp) {
        var resp = resp.responseJSON

        if (resp.success) {
          $("resized_notice").hide();
          $("samples_disabled").show();
          Post.highres();
        } else {
          notice("Error: " + resp.reason)
        }
      }
    })
  },

  destroy: function(id) {
    notice("Deleting record #" + id)

    new Ajax.Request("/user_record/destroy.json", {
      parameters: {
        "id": id
      },
      onComplete: function(resp) {
        if (resp.status == 200) {
          notice("Record deleted")
        } else {
          notice("Access denied")
        }
      }
    })
  },

  current_check: null,
  cancel_check: function() {
    current_check = null;
  },

  /* If background is true, this is a request being made as an indirect result of other
   * input; these can be cancelled (rather, the result is ignord) and are automatically
   * cancelled if another is started while a previous one is still running.
   *
   * If background is false, this is an explicit user action (user submitted the form)
   * and the action must not be cancelled by unrelated background actions.
   */
  reset_password: function(username, email, func) {
    var new_check = new Ajax.Request("/user/reset_password.json", {
      parameters: {
        "user[name]": username,
        "user[email]": email
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON;
        func(resp);
      }
    });
  },
  check: function(username, password, background, func) {
    var parameters = {
      "username": username
    }
    if(password)
      parameters.password = password;

    var new_check = new Ajax.Request("/user/check.json", {
      parameters: parameters,

      onSuccess: function(resp) {
        if(background && resp.request != current_check)
          return;
        current_check = null;

        var resp = resp.responseJSON;
        func(resp);

      }
    });
    if(background)
      current_check = new_check;
  },

  create: function(username, password, email, func) {
    var parameters = {
      "user[name]": username,
      "user[password]": password
    }
    if(email)
      parameters["user[email]"] = email;

    var new_check = new Ajax.Request("/user/create.json", {
      parameters: parameters,

      onComplete: function(resp) {
        var resp = resp.responseJSON;
        func(resp);
      }
    });
  },

  set_login: function(username, pass_hash)
  {
    Cookie.put("login", username)
    Cookie.put("pass_hash", pass_hash)
  },

  check_name_timer: null,
  last_username_in_form: null,
  success_func: null,
  messages: [],

  init: function()
  {
    $("login-popup-notices").select("SPAN").each(function(e) {
      User.messages.push(e.id);
    });

    /*
     * IE makes us jump lots of hoops.  We have to watch submit events on every object
     * instead of just window because IE doesn't support event capturing.  We have to
     * override the submit method in every form to catch programmatic submits, because
     * IE doesn't seem to support initiating events by firing them.
     *
     * Also, since we can't capture events, we need to be sure our submit event is done
     * before other handlers, so if we cancel the event, we prevent other event handlers
     * from continuing.  However, we need to attach after forms have been created.  So,
     * this needs to be run as an early DOMLoaded event, and any other code that attaches
     * submit events to code needs to be run in a later DOMLoaded event (or later events).
     *
     */

    $$("FORM.need-signup").each(function(form) {
      form.observe("submit", User.run_login_onsubmit);
    });

    /* If you select an item from the history dropdown in IE7, change events never fire, so
     * use keyup instead.  This isn't a problem with password fields, since there's no history
     * dropdown. */
    $("login-popup").observe("submit", function(e) {
      e.stop(); 
      User.form_submitted();
    });

    $("login-popup-submit").observe("click", function(e) {
      e.stop();
      User.form_submitted();
    });

    $("login-popup-cancel").observe("click", function(e) { e.stop(); User.close(false); });
    $("login-popup-username").observe("blur", function(e) { User.form_username_blur(); });
    $("login-popup-username").observe("focus", function(e) { User.form_username_focus(); });
    $("login-popup-username").observe("keyup", function(e) { User.form_username_changed(true); });
    $("login-tabs").select("LI").each(function(a) { a.observe("mousedown", function(e) { e.stop(); }); });
    $("login-tabs").select("LI").each(function(a) { a.observe("click", function(e) { e.stop(); User.set_tab(a.id); }); });

    /* IE and FF are glitchy with form submission: they fail to submit forms unless
     * there's an <INPUT type="submit"> somewhere in the form.  IE is even worse:
     * even if there is one, if it's hidden on page load (including if it's a parent
     * element hidden), it'll never submit the form, even if it's shown later.  Don't
     * rely on this behavior; just catch enter presses and submit the form explicitly. */
    OnKey(13, {AllowInputFields: true, Element: $("login-popup")}, function(e)
    {
      e.stop();
      User.form_submitted();
    });

    /* Escape closes the login box. */
    OnKey(27, {AllowInputFields: true, AlwaysAllowOpera: true}, function(e)
    {
      if(!User.success_func)
        return false;

      User.close(false);
      return true;
    });
  },

  open: function(success)
  {
    if(User.success_func)
      User.close(false);
    User.success_func = success;

    $("login-background").show();
    $("login-container").show();

    User.set_tab("tab-login");
  },

  close: function(run_success_func)
  {
    if(!User.success_func)
      return;

    $("login-background").hide();
    $("login-container").hide();
    User.active_tab = null;
    User.check_name_timer = null;
    var func = User.success_func;
    User.success_func = null;

    success_func = null;
    if(run_success_func)
      window.setTimeout(func, 0);
  },

  /* Handle login from an onclick.  If login is not needed, return true.  Otherwise,
   * start the login, and return false; the object will receive another click when
   * the login is successful. */
  run_login_onclick: function(event)
  {
    event = Event.extend(event);

    /* event.target is not copied by clone_event. */
    var target = $(event.target);

    /* event is not available when we get to the callback in IE7. */
    var e = clone_event(event);

    if(User.run_login(true, function() {
        if(target.hasClassName("login-button"))
        {
          /* This is a login button, and not an action that happened to need login.  After
           * a successful login, don't click the button; that'll just go to the login page.
           * Instead, just reload the current page. */
          Cookie.put("notice", "You have been logged in.");
          document.location.reload();
          return;
        }
        target.simulate_anchor_click(e);
      }))
      return true;

    /* Login is running, so stop the event.  Don't just return false; call stop(), so
     * event.stopped is available to the caller if we've been sent this message via
     * Element.dispatchEvent. */
    event.stop();
    return false;
  },

  /* Handle login from an onsubmit.  If login is needed, stop the event and resubmit
   * it when the login completes.  If login is not needed, return and let the submit
   * complete normally. */
  run_login_onsubmit: function(event)
  {
    /* Set skip_complete_on_true, so if we don't need to login, we don't resubmit the
     * event; we just don't cancel it. */
    var target = $(event.target);
    if(!User.run_login(true, function() { target.simulate_submit(); }))
      event.stop();
  },

  /* Handle login.  If we're already logged in, run complete (unless only_complete_on_login
   * is true) and return true.  If we need to log in, start the login dialog; it'll call
   * complete() on successful login. */
  run_login: function(only_complete_on_login, complete)
  {
    if(Cookie.get("login") != "")
    {
      if(!only_complete_on_login)
        complete();
      return true;
    }

    User.open(complete);

    return false;
  },

  active_tab: null,
  set_tab: function(tab)
  {
    if(User.active_tab == tab)
      return;
    User.active_tab = tab;

    User.check_name_timer = null;
    User.last_username_in_form = null;

    $("login-tabs").select("LI").each(function(li) { li.removeClassName("selected"); });
    $("login-tabs").down("#" + tab).addClassName("selected");    


    $$(".tab-header-text").each(function(li) { li.hide(); });
    $(tab + "-text").show();

    if(tab == "tab-login")
    {
      /* If the user's browser fills in a username but no password, focus the password.  Otherwise,
       * focus the username. */
      if($("login-popup-password").value == "" && $("login-popup-username").value != "")
        $("login-popup-password").focus();
      else
        $("login-popup-username").focus();

      User.set_state("login-blank");
    }
    else if(tab == "tab-reset")
    {
      User.set_state("reset-blank");
      $("login-popup-username").focus();
    }
    User.form_username_changed();
  },

  message: function(text)
  {
    for (var i = 0, l = User.messages.length; i < l; i++) {
      var elem = User.messages[i];
      $(elem).hide();
    }

    $("login-popup-message").update(text);
    $("login-popup-message").show();
  },

  set_state: function(state)
  {
    var show = {};
    if(state.match(/^login-/))
    {
      show["login-popup-password-box"] = true;
      if(state == "login-blank")
        $("login-popup-submit").update("Login");
      else if(state == "login-user-exists")
        $("login-popup-submit").update("Login");
      else if(state == "login-confirm-password")
      {
        show["login-popup-password-confirm-box"] = true;
        $("login-popup-submit").update("Create account");
      }
      else if(state == "login-confirm-password-mismatch")
        $("login-popup-submit").update("Create account");
      show["login-popup-" + state] = true;
    }
    else if(state.match(/^reset-/))
    {
      show["login-popup-email-box"] = true;
      $("login-popup-submit").update("Reset password");

      show["login-popup-" + state] = true;
    }

    var all = ["login-popup-email-box", "login-popup-password-box", "login-popup-password-confirm-box"].concat(User.messages);

    current_state = state;
    for (var i = 0, l = all.length; i < l; i++) {
      var elem = all[i];
      if(show[elem])
        $(elem).show();
      else
        $(elem).hide();
    }
  },

  pending_username: null,
  form_username_changed: function(keyup)
  {
    var username = $("login-popup-username").value;
    if(username == User.last_username_in_form)
      return;
    User.last_username_in_form = username;

    User.cancel_check();
    if(User.check_name_timer)
      window.clearTimeout(User.check_name_timer);
    User.pending_username = null;

    if(username == "")
    {
      if(User.active_tab == "tab-login")
        User.set_state("login-blank");
      else if(User.active_tab == "tab-reset")
        User.set_state("reset-blank");
      return;
    }

    /* Delay on keyup, so we don't send tons of requests.  Don't delay otherwise,
     * so we don't introduce lag when we don't have to. */
    var ms = 500;
    if(!keyup && User.check_name_timer)
      ms = 0;

    /*
     * Make sure the UI is still usable if this never finished.  This way, we don't
     * lag the interface if these JSON requests are taking longer than usual; you should
     * be able to click "login" immediately as soon as a username and password are entered.
     * Entering a username and password and clicking "login" should still behave properly
     * if the username doesn't exist and the check_name_timer JSON request hasn't come
     * back yet.
     * 
     * If the state isn't "blank", the button is already enabled.
     */
    User.check_name_timer = window.setTimeout(function() {
      User.check_name_timer = null;
      User.check(username, null, true, function(resp)
      {
        if(resp.exists)
        {
          /* Update the username to match the actual user's case.  If the form contents have
           * changed since we started this check, don't do this.  (We cancel this event if we
           * see the contents change, but the contents can change without this event firing
           * at all.) */
          var current_username = $("login-popup-username").value;
          if(current_username == username)
          {
            /* If the element doesn't have focus, change the text to match.  If it does, wait
             * until it loses focus, so it doesn't interfere with the user editing it. */
            if(!$("login-popup").focused)
              $("login-popup-username").value = resp.name;
            else
              User.pending_username = resp.name;
          }
        }

        if(User.active_tab == "tab-login")
        {
          if(!resp.exists)
          {
            User.set_state("login-confirm-password");
            return;
          }
          else
            User.set_state("login-user-exists");
        }
        else if(User.active_tab == "tab-reset")
        {
          if(!resp.exists)
            User.set_state("reset-blank");
          else if(resp.no_email)
            User.set_state("reset-user-has-no-email");
          else
            User.set_state("reset-user-exists");
        }
      });
    }, ms);
  },

  form_username_focus: function()
  {
    $("login-popup").focused = true;
  },

  form_username_blur: function()
  {
    $("login-popup").focused = false;

    /* When the username field loses focus, update the username case to match the
     * result we got back from check(), if any. */
    if(User.pending_username)
    {
      $("login-popup").username.value = User.pending_username;
      User.pending_username = null;
    }

    /* We watch keyup on the username, because change events are unreliable in IE; update
     * when focus is lost, too, so we see changes made without using the keyboard. */
    User.form_username_changed(false);
  },

  form_submitted: function()
  {
    User.cancel_check();
    if(User.check_name_timer)
      window.clearTimeout(User.check_name_timer);

    var username = $("login-popup-username").value;
    var password = $("login-popup-password").value;
    var password_confirm = $("login-popup-password-confirm").value;
    var email = $("login-popup-email").value;

    if(username == "")
      return;

    if(User.active_tab == "tab-login")
    {
      if(password == "")
      {
        User.message("Please enter a password.");
        return;
      }

      if(current_state == "login-confirm-password")
      {
        if(password != password_confirm)
          User.message("The passwords you've entered don't match.");
        else
        {
          // create account
          User.create(username, password, null, function(resp) {
            if(resp.response == "success")
            {
              User.set_login(resp.name, resp.pass_hash);
              User.close(true);
            }
            else if(resp.response == "error")
            {
              User.message(resp.errors.join("<br>"))
            }
          });
        }
        return;
      }

      User.check(username,  password, false, function(resp)
      {
        if(!resp.exists)
        {
          User.set_state("login-confirm-password");
          return;
        }

        /* We've authenticated successfully.  Our hash is in password_hash; insert the
         * login cookies manually. */
        if(resp.response == "wrong-password")
        {
          notice("Incorrect password");
          return;
        }
        User.set_login(resp.name, resp.pass_hash);
        User.close(true);
      });
    }
    else if(User.active_tab == "tab-reset")
    {
      if(email == "")
        return;

      User.reset_password(username, email, function(resp)
      {
        if(resp.result == "success")
          User.set_state("reset-successful");
        else if(resp.result == "unknown-user")
          User.set_state("reset-unknown-user");
        else if(resp.result == "wrong-email")
          User.set_state("reset-user-email-incorrect");
        else if(resp.result == "no-email")
          User.set_state("reset-user-has-no-email");
        else if(resp.result == "invalid-email")
          User.set_state("reset-user-email-invalid");
      });
    }
  },

  modify_blacklist: function(add, remove, success)
  {
    new Ajax.Request("/user/modify_blacklist.json", {
      parameters: {
        "add[]": add,
        "remove[]": remove
      },
      onComplete: function(resp) {
        var resp = resp.responseJSON;

        if (resp.success)
        {
          if(success) success(resp);
        } else {
          notice("Error: " + resp.reason);
        }
      }
    });
  },

  set_pool_browse_mode: function(browse_mode) {
    new Ajax.Request("/user/update.json", {
      parameters: {
        "user[pool_browse_mode]": browse_mode
      },

      onComplete: function(resp) {
        var resp = resp.responseJSON;

        if (resp.success) {
          window.location.reload();
        } else {
          notice("Error: " + resp.reason);
        }
      }
    });
  },

  get_current_user_info: function()
  {
    var user_info = Cookie.get("user_info");
    if(!user_info)
      return null;
    return user_info.split(";");
  },
  get_current_user_id: function()
  {
    var user_info = User.get_current_user_info();
    if(!user_info)
      return 0;
    return parseInt(user_info[0]);
  },

  get_current_user_level: function()
  {
    var user_info = User.get_current_user_info();
    if(!user_info)
      return 0;
    return parseInt(user_info[1]);
  }
}

/* This should be done in User.init(), but that doesn't work in IE (for some reason). */
Element.addMethods("FORM", {
  submitWithLogin: function(form)
  {
    if(!form.hasClassName("need-signup"))
    {
      form.submit();
      return;
    }

    User.run_login(false, function() { form.submit() });
  }
});

