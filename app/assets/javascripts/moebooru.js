(function ($) {
  Moebooru = {};
  Moe = $(Moebooru);

  Moebooru.path = function (url) {
    return PREFIX === '/' ? url : PREFIX + url;
  }

  // XXX: Tested on chrome, mozilla, msie(9/10)
  // might or might not works in other browser
  Moebooru.dragElement = function(el) {
    var win = $(window), doc = $(document),
        prevPos = {x:-1, y:-1},
        lclick = 0;

    el.on('dragstart', function () { return false; });

    el.on('mousedown', function (e) {
      if (e.which === 1) {
        lclick = 1;
        el.css('cursor', 'pointer');
        prevPos = {x: e.clientX, y: e.clientY};
      }
      return false;
    });

    el.on('mousemove', function (e) {
      if (lclick) {
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
      prevPos.x = x; prevPos.y = y;
      return offset;
    }
  }
})(jQuery);
