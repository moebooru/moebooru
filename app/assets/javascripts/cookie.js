// FIXME: I think the correct way would be replacing all calls to this
//        with jQuery.cookie.
(function($) {
  $.cookie.defaults['path'] = PREFIX;
  $.cookie.defaults['expires'] = 365;
  window.Cookie = {
    put: function(name, value, days) {
      var options = null;
      if (days) {
        options = { expires: days };
      };
      $.cookie(name, value, options);
    },

    get: function(name) {
      // FIXME: compatibility reason. Should sweep this with !! check
      //        or something similar in relevant codes.
      return $.cookie(name) || '';
    },

    get_int: function(name) {
      parseInt($.cookie(name));
    },

    remove: function(name) {
      $.removeCookie(name);
    },

    unescape: function(value) {
      return window.decodeURIComponent(value.replace(/\+/g, " "))
    }
  };
}) (jQuery);
