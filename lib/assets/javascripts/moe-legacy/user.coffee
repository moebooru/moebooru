window.User =
  cancel_check: ->
    window.current_check = null
    return
  reset_password: (username, email, func) ->
    new_check = new (Ajax.Request)('/user/reset_password.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters:
        'user[name]': username
        'user[email]': email
      onComplete: (resp) ->
        resp = resp.responseJSON
        func resp
        return
)
    return
  check: (username, password, background, func) ->
    parameters = 'username': username
    if password
      parameters.password = password
    new_check = new (Ajax.Request)('/user/check.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters: parameters
      onSuccess: (resp) ->
        if background and resp.request != window.current_check
          return
        window.current_check = null
        resp = resp.responseJSON
        func resp
        return
)
    if background
      window.current_check = new_check
    return
  create: (username, password, email, func) ->
    parameters = 
      'user[name]': username
      'user[password]': password
    if email
      parameters['user[email]'] = email
    new_check = new (Ajax.Request)('/user/create.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters: parameters
      onComplete: (resp) ->
        resp = resp.responseJSON
        func resp
        return
)
    return
  set_login: (username, pass_hash, user_info) ->
    Cookie.put 'login', username
    Cookie.put 'pass_hash', pass_hash
    Cookie.put 'user_info', user_info
    return
  check_name_timer: null
  last_username_in_form: null
  success_func: null
  messages: []
  init: ->
    $('login-popup-notices').select('SPAN').each (e) ->
      User.messages.push e.id
      return

    ###
    # IE makes us jump lots of hoops.  We have to watch submit events on every object
    # instead of just window because IE doesn't support event capturing.  We have to
    # override the submit method in every form to catch programmatic submits, because
    # IE doesn't seem to support initiating events by firing them.
    #
    # Also, since we can't capture events, we need to be sure our submit event is done
    # before other handlers, so if we cancel the event, we prevent other event handlers
    # from continuing.  However, we need to attach after forms have been created.  So,
    # this needs to be run as an early DOMLoaded event, and any other code that attaches
    # submit events to code needs to be run in a later DOMLoaded event (or later events).
    #
    ###

    $$('FORM.need-signup').each (form) ->
      form.observe 'submit', User.run_login_onsubmit
      return

    ### If you select an item from the history dropdown in IE7, change events never fire, so
    # use keyup instead.  This isn't a problem with password fields, since there's no history
    # dropdown. 
    ###

    $('login-popup').observe 'submit', (e) ->
      e.stop()
      User.form_submitted()
      return
    $('login-popup-submit').observe 'click', (e) ->
      e.stop()
      User.form_submitted()
      return
    $('login-popup-cancel').observe 'click', (e) ->
      e.stop()
      User.close false
      return
    $('login-popup-username').observe 'blur', (e) ->
      User.form_username_blur()
      return
    $('login-popup-username').observe 'focus', (e) ->
      User.form_username_focus()
      return
    $('login-popup-username').observe 'keyup', (e) ->
      User.form_username_changed true
      return
    $('login-tabs').select('LI').each (a) ->
      a.observe 'mousedown', (e) ->
        e.stop()
        return
      return
    $('login-tabs').select('LI').each (a) ->
      a.observe 'click', (e) ->
        e.stop()
        User.set_tab a.id
        return
      return

    ### IE and FF are glitchy with form submission: they fail to submit forms unless
    # there's an <INPUT type="submit"> somewhere in the form.  IE is even worse:
    # even if there is one, if it's hidden on page load (including if it's a parent
    # element hidden), it'll never submit the form, even if it's shown later.  Don't
    # rely on this behavior; just catch enter presses and submit the form explicitly. 
    ###

    OnKey 13, {
      AllowInputFields: true
      Element: $('login-popup')
    }, (e) ->
      e.stop()
      User.form_submitted()
      return

    ### Escape closes the login box. ###

    OnKey 27, {
      AllowInputFields: true
      AlwaysAllowOpera: true
    }, (e) ->
      if !User.success_func
        return false
      User.close false
      true
    return
  open: (success) ->
    if User.success_func
      User.close false
    User.success_func = success
    $('login-background').show()
    $('login-container').show()
    User.set_tab 'tab-login'
    return
  close: (run_success_func) ->
    if !User.success_func
      return
    $('login-background').hide()
    $('login-container').hide()
    User.active_tab = null
    User.check_name_timer = null
    func = User.success_func
    User.success_func = null
    if run_success_func
      window.setTimeout func, 0
    return
  run_login_onclick: (event) ->
    event = Event.extend(event)

    ### event.target is not copied by clone_event. ###

    target = $(event.target)

    ### event is not available when we get to the callback in IE7. ###

    e = clone_event(event)
    if User.run_login(true, (->
        if target.hasClassName('login-button')

          ### This is a login button, and not an action that happened to need login.  After
          # a successful login, don't click the button; that'll just go to the login page.
          # Instead, just reload the current page. 
          ###

          Cookie.put 'notice', 'You have been logged in.'
          document.location.reload()
          return
        target.simulate_anchor_click e
        return
      ))
      return true

    ### Login is running, so stop the event.  Don't just return false; call stop(), so
    # event.stopped is available to the caller if we've been sent this message via
    # Element.dispatchEvent. 
    ###

    event.stop()
    false
  run_login_onsubmit: (event) ->

    ### Set skip_complete_on_true, so if we don't need to login, we don't resubmit the
    # event; we just don't cancel it. 
    ###

    target = $(event.target)
    if !User.run_login(true, (->
        target.simulate_submit()
        return
      ))
      event.stop()
    return
  run_login: (only_complete_on_login, complete) ->
    if Cookie.get('login') != ''
      if !only_complete_on_login
        complete()
      return true
    User.open complete
    false
  active_tab: null
  set_tab: (tab) ->
    if User.active_tab == tab
      return
    User.active_tab = tab
    User.check_name_timer = null
    User.last_username_in_form = null
    $('login-tabs').select('LI').each (li) ->
      li.removeClassName 'selected'
      return
    $('login-tabs').down('#' + tab).addClassName 'selected'
    $$('.tab-header-text').each (li) ->
      li.hide()
      return
    $(tab + '-text').show()
    if tab == 'tab-login'

      ### If the user's browser fills in a username but no password, focus the password.  Otherwise,
      # focus the username. 
      ###

      if $('login-popup-password').value == '' and $('login-popup-username').value != ''
        $('login-popup-password').focus()
      else
        $('login-popup-username').focus()
      User.set_state 'login-blank'
    else if tab == 'tab-reset'
      User.set_state 'reset-blank'
      $('login-popup-username').focus()
    User.form_username_changed()
    return
  message: (text) ->
    i = 0
    l = User.messages.length
    while i < l
      elem = User.messages[i]
      $(elem).hide()
      i++
    $('login-popup-message').update text
    $('login-popup-message').show()
    return
  set_state: (state) ->
    show = {}
    if state.match(/^login-/)
      show['login-popup-password-box'] = true
      if state == 'login-blank'
        $('login-popup-submit').update 'Login'
      else if state == 'login-user-exists'
        $('login-popup-submit').update 'Login'
      else if state == 'login-confirm-password'
        show['login-popup-password-confirm-box'] = true
        $('login-popup-submit').update 'Create account'
      else if state == 'login-confirm-password-mismatch'
        $('login-popup-submit').update 'Create account'
      show['login-popup-' + state] = true
    else if state.match(/^reset-/)
      show['login-popup-email-box'] = true
      $('login-popup-submit').update 'Reset password'
      show['login-popup-' + state] = true
    all = [
      'login-popup-email-box'
      'login-popup-password-box'
      'login-popup-password-confirm-box'
    ].concat(User.messages)
    window.current_state = state
    i = 0
    l = all.length
    while i < l
      elem = all[i]
      if show[elem]
        $(elem).show()
      else
        $(elem).hide()
      i++
    return
  pending_username: null
  form_username_changed: (keyup) ->
    username = $('login-popup-username').value
    if username == User.last_username_in_form
      return
    User.last_username_in_form = username
    User.cancel_check()
    if User.check_name_timer
      window.clearTimeout User.check_name_timer
    User.pending_username = null
    if username == ''
      if User.active_tab == 'tab-login'
        User.set_state 'login-blank'
      else if User.active_tab == 'tab-reset'
        User.set_state 'reset-blank'
      return

    ### Delay on keyup, so we don't send tons of requests.  Don't delay otherwise,
    # so we don't introduce lag when we don't have to. 
    ###

    ms = 500
    if !keyup and User.check_name_timer
      ms = 0

    ###
    # Make sure the UI is still usable if this never finished.  This way, we don't
    # lag the interface if these JSON requests are taking longer than usual; you should
    # be able to click "login" immediately as soon as a username and password are entered.
    # Entering a username and password and clicking "login" should still behave properly
    # if the username doesn't exist and the check_name_timer JSON request hasn't come
    # back yet.
    #
    # If the state isn't "blank", the button is already enabled.
    ###

    User.check_name_timer = window.setTimeout((->
      User.check_name_timer = null
      User.check username, null, true, (resp) ->
        if resp.exists

          ### Update the username to match the actual user's case.  If the form contents have
          # changed since we started this check, don't do this.  (We cancel this event if we
          # see the contents change, but the contents can change without this event firing
          # at all.) 
          ###

          current_username = $('login-popup-username').value
          if current_username == username

            ### If the element doesn't have focus, change the text to match.  If it does, wait
            # until it loses focus, so it doesn't interfere with the user editing it. 
            ###

            if !$('login-popup').focused
              $('login-popup-username').value = resp.name
            else
              User.pending_username = resp.name
        if User.active_tab == 'tab-login'
          if !resp.exists
            User.set_state 'login-confirm-password'
            return
          else
            User.set_state 'login-user-exists'
        else if User.active_tab == 'tab-reset'
          if !resp.exists
            User.set_state 'reset-blank'
          else if resp.no_email
            User.set_state 'reset-user-has-no-email'
          else
            User.set_state 'reset-user-exists'
        return
      return
    ), ms)
    return
  form_username_focus: ->
    $('login-popup').focused = true
    return
  form_username_blur: ->
    $('login-popup').focused = false

    ### When the username field loses focus, update the username case to match the
    # result we got back from check(), if any. 
    ###

    if User.pending_username
      $('login-popup').username.value = User.pending_username
      User.pending_username = null

    ### We watch keyup on the username, because change events are unreliable in IE; update
    # when focus is lost, too, so we see changes made without using the keyboard. 
    ###

    User.form_username_changed false
    return
  form_submitted: ->
    User.cancel_check()
    if User.check_name_timer
      window.clearTimeout User.check_name_timer
    username = $('login-popup-username').value
    password = $('login-popup-password').value
    password_confirm = $('login-popup-password-confirm').value
    email = $('login-popup-email').value
    if username == ''
      return
    if User.active_tab == 'tab-login'
      if password == ''
        User.message 'Please enter a password.'
        return
      if window.current_state == 'login-confirm-password'
        if password != password_confirm
          User.message 'The passwords you\'ve entered don\'t match.'
        else
          # create account
          User.create username, password, null, (resp) ->
            if resp.response == 'success'
              User.set_login resp.name, resp.pass_hash, resp.user_info
              User.close true
            else if resp.response == 'error'
              User.message resp.errors.join('<br>')
            return
        return
      User.check username, password, false, (resp) ->
        if !resp.exists
          User.set_state 'login-confirm-password'
          return

        ### We've authenticated successfully.  Our hash is in password_hash; insert the
        # login cookies manually. 
        ###

        if resp.response == 'wrong-password'
          notice 'Incorrect password'
          return
        User.set_login resp.name, resp.pass_hash, resp.user_info
        User.close true
        return
    else if User.active_tab == 'tab-reset'
      if email == ''
        return
      User.reset_password username, email, (resp) ->
        if resp.result == 'success'
          User.set_state 'reset-successful'
        else if resp.result == 'unknown-user'
          User.set_state 'reset-unknown-user'
        else if resp.result == 'wrong-email'
          User.set_state 'reset-user-email-incorrect'
        else if resp.result == 'no-email'
          User.set_state 'reset-user-has-no-email'
        else if resp.result == 'invalid-email'
          User.set_state 'reset-user-email-invalid'
        return
    return
  modify_blacklist: (add, remove, success) ->
    new (Ajax.Request)('/user/modify_blacklist.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters:
        'add[]': add
        'remove[]': remove
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          if success
            success resp
        else
          notice 'Error: ' + resp.reason
        return
)
    return
  set_pool_browse_mode: (browse_mode) ->
    new (Ajax.Request)('/user/update.json',
      requestHeaders: 'X-CSRF-Token': jQuery('meta[name=csrf-token]').attr('content')
      parameters: 'user[pool_browse_mode]': browse_mode
      onComplete: (resp) ->
        resp = resp.responseJSON
        if resp.success
          window.location.reload()
        else
          notice 'Error: ' + resp.reason
        return
)
    return
  get_current_user_info: ->
    user_info = Cookie.get('user_info')
    if !user_info
      return null
    user_info.split ';'
  get_current_user_info_field: (idx, def) ->
    user_info = User.get_current_user_info()
    if !user_info
      return def
    if idx >= user_info.length
      return def
    user_info[idx]
  get_current_user_id: ->
    parseInt User.get_current_user_info_field(0, 0)
  get_current_user_level: ->
    parseInt User.get_current_user_info_field(1, 0)
  get_use_browser: ->
    setting = User.get_current_user_info_field(2, '0')
    setting == '1'
  is_member_or_higher: ->
    User.get_current_user_level() >= 20
  is_mod_or_higher: ->
    User.get_current_user_level() >= 40
