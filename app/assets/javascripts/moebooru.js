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

  // XXX: Tested on chrome canary
  // might or might not works in other browser
  //
  // TODO: Handle touch events and another fancy related events
  // for mobile browser
  Moebooru.dragElement = function(el) {
    var win = $(window), doc = $(document),
        prevPos = {x:-1, y:-1};
    el.on('dragstart', function () { return false; });
    el.on('mousedown', function (e) {
      prevPos = { x: e.clientX, y: e.clientY }
    });
    el.on('mousemove', function (e) {
      if (e.which === 1) {
        scrollTo(currentX(e.clientX), currentY(e.clientY));
      }
    });

    // XXX: This two functions below should
    // probably refactored into one function?
    function currentX(n) {
      var max = doc.width() - win.width(),
          offset = window.scrollX + (prevPos.x - n);
      if (prevPos.x === n) offset = window.scrollX;
      prevPos.x = n;
      if (offset < 0) return 0;
      if (offset > max) return max;
      return offset;
    }

    function currentY(n) {
      var max = doc.height() - win.height(),
          offset = window.scrollY + (prevPos.y - n);
      if (prevPos.y === n) offset = window.scrollY;
      prevPos.y = n;
      if (offset < 0) return 0;
      if (offset > max) return max;
      return offset;
    }
  }
})(jQuery);
