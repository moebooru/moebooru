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



  // XXX: Tested on chrome, mozilla, msie(9/10)
  // might or might not works in other browser
  Moebooru.dragElement = function(el) {
    var win = $(window), doc = $(document),
        prevPos = {x:-1, y:-1},
        button = 0;

    el.on('dragstart', function () { return false; });

    el.on('mousedown', function (e) {
      if (e.which === 1) {
        button = e.which;
        el.css('cursor', 'pointer');
        prevPos = {x: e.clientX, y: e.clientY};
      }
      return false;
    });

    el.on('mousemove', function (e) {
      if (button === 1) {
        var scroll = current(e.clientX, e.clientY);
        scrollTo(scroll[0], scroll[1]);
      }
      return false;
    });

    doc.on('mouseup', function (e) {
      button = 0;
      el.css('cursor', 'auto');
      return false;
    });

    function current(x, y) {
      var off = [window.pageXOffset || document.documentElement.scrollLeft||document.body.scrollLeft,
                 window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop],
          offset = [off[0] + (prevPos.x - x), off[1] + (prevPos.y - y)];
      offset[0] = (prevPos.x === x) ? off[0] : offset[0];
      offset[1] = (prevPos.y === y) ? off[1] : offset[1];
      prevPos.x = x; prevPos.y = y;
      return offset;
    }
  }
})(jQuery);
