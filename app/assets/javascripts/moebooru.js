(function ($) {
  Moebooru = {
    '__slug__': {}
  };
  Moe = $(Moebooru);

  Moebooru.addData = function (data) {
    if (data.posts)
      Moe.trigger("post:add", [data.posts]);
    if (data.tags)
      Moe.trigger("tag:add", [data.tags]);
    if (data.votes)
      Moe.trigger("vote:add", [data.votes]);
    if (data.voted_by)
      Moe.trigger("vote:add_user_list", [data.voted_by]);
    if (data.pools)
      Moe.trigger("pool:add", [data.pools]);
    if (data.pool_posts)
      Moe.trigger("pool:add_post", {
        pool_posts: data.pool_posts,
        posts: data.posts
      });
  };

  Moebooru.attach = function (key, obj) {
    Moebooru['__slug__'][key] = obj;
  };

  Moebooru.get = function (key) {
   return Moebooru['__slug__'][key];
  };

  Moebooru.request = function (url, params/*, type */) {
    $.ajax({
      url: Moebooru.path(url),
      type: arguments[2] || 'POST',
      dataType: 'json',
      data: params,
      statusCode: {
        403: function () {
          notice(t('error')+': '+t('denied'));
        }
      }
    }).done(function (data) {
      Moe.trigger(url+":ready", [data]);
    }).fail(function () {
      notice(t('error'));
    });
  };

  Moebooru.path = function (url) {
    return PREFIX === '/' ? url : PREFIX + url;
  }



  // XXX: Tested on chrome, mozilla, msie10
  // might or might not works in other browser
  //
  // XXX: mousemove event for msie9 (and below, probably)
  // doesn't emmit distinguishable button(?)
  // should create some workaround 
  Moebooru.dragElement = function(el) {
    var win = $(window), doc = $(document),
        prevPos = {x:-1, y:-1},
        ie9Button = 0 /*Workaround for msie9*/;

    el.on('dragstart', function () { return false; });

    el.on('mousedown', function (e) {
      prevPos = {x: e.clientX, y: e.clientY};
      ie9Button = e.buttons;
      return false;
    });

    el.on('mousemove', function (e) {
      if (getMouseButton(e) === 1) {
        var scroll = current(e.clientX, e.clientY);
        scrollTo(scroll[0], scroll[1]);
      }
      return false;
    });

    el.on('mouseup', function (e) { ie9Button = 0; });

    function getMouseButton(e) {
      var b = $.browser;
      if (b.msie) return ie9Button;
      if (b.mozilla) return e.buttons;
      if (b.webkit || b.chrome) return e.which;
    }

    function current(x, y) {
      var max = [doc.width() - win.width(), doc.height() - win.height()],
          off = [window.pageXOffset || document.documentElement.scrollLeft ||
                 document.body.scrollLeft, window.pageYOffset ||
                 document.documentElement.scrollTop || document.body.scrollTop],
          offset = [off[0] + (prevPos.x - x), off[1] + (prevPos.y - y)];
      offset[0] = (prevPos.x === x) ? off[0] : offset[0];
      offset[1] = (prevPos.y === y) ? off[1] : offset[1];
      prevPos.x = x; prevPos.y = y;
      return offset;
    }
  }
})(jQuery);
