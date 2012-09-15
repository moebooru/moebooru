Cookie = {
  put: function(name, value, days) {
    if (days == null) {
      days = 365
    }

    var date = new Date()
    date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000))
    var expires = "; expires=" + date.toGMTString()
    document.cookie = name + "=" + window.encodeURIComponent(value) + expires + "; path=/"
  },

  raw_get: function(name) {
    var nameEq = name + "="
    var ca = document.cookie.split(";")

    for (var i = 0; i < ca.length; ++i) {
      var c = ca[i]

      while (c.charAt(0) == " ") {
        c = c.substring(1, c.length)
      }

      if (c.indexOf(nameEq) == 0) {
        return c.substring(nameEq.length, c.length)
      }
    }

    return ""
  },

  get: function(name) {
    return this.unescape(this.raw_get(name))
  },

  get_int: function(name) {
    var value = Cookie.get(name);
    value = parseInt(value);
    if(value)
      return value;
    else
      return 0;
  },

  remove: function(name) {
    Cookie.put(name, "", -1)
  },

  unescape: function(val) {
    return window.decodeURIComponent(val.replace(/\+/g, " "))
  },

  setup: function() {
    if (location.href.match(/^\/(comment|pool|note|post)/) && this.get("tos") != "1") {
      // Setting location.pathname in Safari doesn't work, so manually extract the domain.
      var domain = location.href.match(/^(http:\/\/[^\/]+)/)[0]
      location.href = domain + "/static/terms_of_service?url=" + location.href
      return
    }

		if (this.get("hide-upgrade-account") == "1") {
      if ($("upgrade-account")) {
   	    $("upgrade-account").hide()
      }
		}

    if ($("my-favorites")) {
      if (this.get("login") != "") {
        $("my-favorites").href = "/post/index?tags=vote%3A3%3A" + Cookie.get("login") + "%20order%3Avote"
      } else {
        $("my-favorites-container").hide()
      }
    }
  }
}
