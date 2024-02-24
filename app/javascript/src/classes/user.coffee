$ = jQuery

export default class User
  constructor: ->
    @active_tab = null
    @checkXhr = null
    @current_state = null
    @pending_username = null
    @check_name_timer = null
    @last_username_in_form = null
    @success_func = null
    @messages = []

  cancel_check: =>
    @checkXhr?.abort()

  reset_password: (username, email, func) ->
    $.ajax '/user/reset_password.json',
      data:
        user:
          name: username
          email: email
      dataType: 'json'
      method: 'POST'
    .done func
    .fail (xhr) ->
      json = xhr.responseJSON
      if json?
        func json
      else
        notice "Error: unknown error"

  check: (username, password, background, func) =>
    parameters = username: username
    if password
      parameters.password = password

    @cancel_check()
    @checkXhr = $.ajax '/user/check.json',
      data: parameters
      dataType: 'json'
      method: 'POST'
    .done func

    return

  create: (username, password, email, func) ->
    parameters =
      user:
        name: username
        password: password
    if email
      parameters.user.email = email

    $.ajax '/user/create.json',
      data: parameters
      dataType: 'json'
      method: 'POST'
    .done func

    return

  init: =>
    for notice in document.querySelectorAll('#login-popup-notices span')
      @messages.push notice.id

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
    for form in document.querySelectorAll('form.need-signup')
      form.addEventListener 'submit', @run_login_onsubmit

    # If you select an item from the history dropdown in IE7, change events never fire, so
    # use keyup instead.  This isn't a problem with password fields, since there's no history
    # dropdown.
    document.getElementById('login-popup').addEventListener 'submit', (e) =>
      e.stopPropagation()
      e.preventDefault()
      @form_submitted()
      return

    document.getElementById('login-popup-submit').addEventListener 'click', (e) =>
      e.stopPropagation()
      e.preventDefault()
      @form_submitted()
      return

    document.getElementById('login-popup-cancel').addEventListener 'click', (e) =>
      e.stopPropagation()
      e.preventDefault()
      @close false
      return

    document.getElementById('login-popup-username').addEventListener 'blur', (e) =>
      @form_username_blur()
      return

    document.getElementById('login-popup-username').addEventListener 'focus', (e) =>
      @form_username_focus()
      return

    document.getElementById('login-popup-username').addEventListener 'keyup', (e) =>
      @form_username_changed true
      return

    for a in document.querySelectorAll('#login-tabs li')
      do (a) =>
        a.addEventListener 'mousedown', (e) =>
          e.stopPropagation()
          e.preventDefault()
        a.addEventListener 'click', (e) =>
          e.stopPropagation()
          e.preventDefault()
          @set_tab a.id

    # IE and FF are glitchy with form submission: they fail to submit forms unless
    # there's an <INPUT type="submit"> somewhere in the form.  IE is even worse:
    # even if there is one, if it's hidden on page load (including if it's a parent
    # element hidden), it'll never submit the form, even if it's shown later.  Don't
    # rely on this behavior; just catch enter presses and submit the form explicitly.
    OnKey 13, {
      AllowInputFields: true
      Element: document.getElementById('login-popup')
    }, (e) =>
      e.stop()
      @form_submitted()
      return

    # Escape closes the login box.
    OnKey 27, {
      AllowInputFields: true
      AlwaysAllowOpera: true
    }, (e) =>
      return false if !@success_func
      @close false
      true

  open: (success) =>
    if @success_func
      @close false
    @success_func = success
    document.getElementById('login-background').style.display = ''
    document.getElementById('login-container').style.display = ''
    @set_tab 'tab-login'

  close: (run_success_func) =>
    return if !@success_func
    document.getElementById('login-background').style.display = 'none'
    document.getElementById('login-container').style.display = 'none'
    @active_tab = null
    @check_name_timer = null
    func = @success_func
    @success_func = null
    if run_success_func
      window.setTimeout func, 0
    return

  run_login_onclick: (event) =>
    target = event.target

    loggedIn = @run_login true, =>
      target.click()
      return

    return true if loggedIn

    # Login is running, so stop the event.  Don't just return false; call stop(), so
    # event.stopped is available to the caller if we've been sent this message via
    # Element.dispatchEvent.
    event.stopPropagation()
    event.preventDefault()
    false

  run_login_onsubmit: (event) =>
    # Set skip_complete_on_true, so if we don't need to login, we don't resubmit the
    # event; we just don't cancel it.
    target = event.target
    loggedIn = @run_login true, =>
      target.requestSubmit()
      return

    return true if loggedIn

    event.stopPropagation()
    event.preventDefault()
    false

  run_login: (only_complete_on_login, complete) =>
    if Cookie.get('user_info') != ''
      if !only_complete_on_login
        complete()
      return true
    @open complete
    false

  set_tab: (tab) =>
    if @active_tab == tab
      return
    @active_tab = tab
    @check_name_timer = null
    @last_username_in_form = null
    for li in document.querySelectorAll('#login-tabs li')
      li.classList.remove 'selected'

    document.getElementById(tab).classList.add 'selected'
    for li in document.querySelectorAll('.tab-header-text')
      li.style.display = 'none'

    document.getElementById("#{tab}-text").style.display = ''

    usernameInput = document.getElementById 'login-popup-username'
    if tab == 'tab-login'
      # If the user's browser fills in a username but no password, focus the password.  Otherwise,
      # focus the username.
      passwordInput = document.getElementById 'login-popup-password'
      if passwordInput.value == '' && usernameInput.value != ''
        passwordInput.focus()
      else
        usernameInput.focus()
      @set_state 'login-blank'
    else if tab == 'tab-reset'
      @set_state 'reset-blank'
      usernameInput.focus()

    @form_username_changed()
    return

  message: (text) =>
    for messageId in @messages
      document.getElementById(messageId).style.display = 'none'

    messageEl = document.getElementById('login-popup-message')
    messageEl.innerHTML = text
    messageEl.style.display = ''
    return

  set_state: (state) =>
    show = {}
    if state.match(/^login-/)
      show['login-popup-password-box'] = true
      if state == 'login-blank'
        document.getElementById('login-popup-submit').innerText = 'Login'
      else if state == 'login-user-exists'
        document.getElementById('login-popup-submit').innerText = 'Login'
      else if state == 'login-confirm-password'
        show['login-popup-password-confirm-box'] = true
        document.getElementById('login-popup-submit').innerText = 'Create account'
      else if state == 'login-confirm-password-mismatch'
        document.getElementById('login-popup-submit').innerText = 'Create account'
      show["login-popup-#{state}"] = true
    else if state.match(/^reset-/)
      show['login-popup-email-box'] = true
      document.getElementById('login-popup-submit').innerText = 'Reset password'
      show["login-popup-#{state}"] = true
    all = [
      'login-popup-email-box'
      'login-popup-password-box'
      'login-popup-password-confirm-box'
      ...@messages
    ]
    @current_state = state
    for id in all
      document.getElementById(id).style.display =
        if show[id]
          ''
        else
          'none'
    return

  form_username_changed: (keyup) =>
    username = document.getElementById('login-popup-username').value
    if username == @last_username_in_form
      return
    @last_username_in_form = username
    @cancel_check()
    window.clearTimeout @check_name_timer
    @pending_username = null
    if username == ''
      if @active_tab == 'tab-login'
        @set_state 'login-blank'
      else if @active_tab == 'tab-reset'
        @set_state 'reset-blank'
      return

    # Delay on keyup, so we don't send tons of requests.  Don't delay otherwise,
    # so we don't introduce lag when we don't have to.
    ms = 500
    if !keyup and @check_name_timer
      ms = 0

    # Make sure the UI is still usable if this never finished.  This way, we don't
    # lag the interface if these JSON requests are taking longer than usual; you should
    # be able to click "login" immediately as soon as a username and password are entered.
    # Entering a username and password and clicking "login" should still behave properly
    # if the username doesn't exist and the check_name_timer JSON request hasn't come
    # back yet.
    #
    # If the state isn't "blank", the button is already enabled.
    checkName = =>
      @check_name_timer = null
      @check username, null, true, (resp) =>
        if resp.exists
          # Update the username to match the actual user's case.  If the form contents have
          # changed since we started this check, don't do this.  (We cancel this event if we
          # see the contents change, but the contents can change without this event firing
          # at all.)
          usernameInput = document.getElementById('login-popup-username')
          current_username = usernameInput.value
          if current_username == username
            # If the element doesn't have focus, change the text to match.  If it does, wait
            # until it loses focus, so it doesn't interfere with the user editing it.
            if !document.getElementById('login-popup').focused
              usernameInput.value = resp.name
            else
              @pending_username = resp.name
        if @active_tab == 'tab-login'
          if !resp.exists
            @set_state 'login-confirm-password'
          else
            @set_state 'login-user-exists'
        else if @active_tab == 'tab-reset'
          if !resp.exists
            @set_state 'reset-blank'
          else if resp.no_email
            @set_state 'reset-user-has-no-email'
          else
            @set_state 'reset-user-exists'

    @check_name_timer = window.setTimeout(checkName, ms)
    return

  form_username_focus: ->
    document.getElementById('login-popup').focused = true
    return

  form_username_blur: =>
    document.getElementById('login-popup').focused = false

    # When the username field loses focus, update the username case to match the
    # result we got back from check(), if any.
    if @pending_username
      document.getElementById('login-popup').username.value = @pending_username
      @pending_username = null

    # We watch keyup on the username, because change events are unreliable in IE; update
    # when focus is lost, too, so we see changes made without using the keyboard.
    @form_username_changed false
    return

  form_submitted: =>
    @cancel_check()
    window.clearTimeout @check_name_timer
    username = document.getElementById('login-popup-username').value
    password = document.getElementById('login-popup-password').value
    password_confirm = document.getElementById('login-popup-password-confirm').value
    email = document.getElementById('login-popup-email').value
    return if username == ''

    if @active_tab == 'tab-login'
      if password == ''
        @message 'Please enter a password.'
        return
      if @current_state == 'login-confirm-password'
        if password != password_confirm
          @message "The passwords you've entered don't match."
        else
          # create account
          @create username, password, null, (resp) =>
            if resp.response == 'success'
              @close true
            else if resp.response == 'error'
              @message resp.errors.join('<br>')
        return

      @check username, password, false, (resp) =>
        if !resp.exists
          @set_state 'login-confirm-password'
          return

        if resp.response == 'wrong-password'
          notice 'Incorrect password'
          return
        @close true
        return

    else if @active_tab == 'tab-reset'
      if email == ''
        return

      @reset_password username, email, (resp) =>
        newState = switch resp.result
          when 'success' then 'reset-successful'
          when 'unknown-user' then 'reset-unknown-user'
          when 'wrong-email' then 'reset-user-email-incorrect'
          when 'no-email' then 'reset-user-has-no-email'
          when 'invalid-email' then 'reset-user-email-invalid'
        @set_state newState if newState?
        return
    return

  modify_blacklist: (add, remove, success) =>
    $.ajax '/user/modify_blacklist.json',
      data:
        add: add
        remove: remove
      dataType: 'json'
      method: 'POST'
    .done (resp) ->
      success?(resp)
    .fail (xhr) ->
      notice "Error: #{xhr.responseJSON?.reason ? 'unknown error'}"

    return

  set_pool_browse_mode: (browse_mode) ->
    $.ajax '/user/update.json',
      data:
        user:
          pool_browse_mode: browse_mode
      dataType: 'json'
      method: 'POST'
    .done (resp) ->
      window.location.reload()
    .fail (xhr) ->
      notice "Error: #{xhr.responseJSON?.reason ? 'unknown error'}"

    return

  get_current_user_info: ->
    user_info = Cookie.get('user_info')
    return null if !user_info

    user_info.split ';'

  get_current_user_info_field: (idx, def) =>
    user_info = @get_current_user_info()
    if !user_info
      return def

    user_info[idx] ? def

  get_current_user_id: =>
    parseInt @get_current_user_info_field(0, 0)

  get_current_user_level: =>
    parseInt @get_current_user_info_field(1, 0)

  get_use_browser: =>
    @get_current_user_info_field(2, '0') == '1'

  is_member_or_higher: =>
    @get_current_user_level() >= 20

  is_mod_or_higher: =>
    @get_current_user_level() >= 40
