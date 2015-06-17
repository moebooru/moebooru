(function ($) {
  window.Moebooru = {};
  window.Moe = $(Moebooru);

  Moebooru.path = function (url) {
    return PREFIX === '/' ? url : PREFIX + url;
  }

  // XXX: Tested on chrome, mozilla, msie(9/10)
  // might or might not works in other browser
  Moebooru.dragElement = function(el) {
    var win = $(window),
        doc = $(document),
        prevPos = [];

    el.on('dragstart', function () { return false; });

    el.on('mousedown', function (e) {
      if (e.which === 1) {
        var pageScroller = function(e) {
          var scroll = current(e.clientX, e.clientY);
          scrollTo(scroll[0], scroll[1]);
          return false;
        };
        el.css('cursor', 'pointer');
        prevPos = [e.clientX, e.clientY];
        doc.on('mousemove', pageScroller);
        doc.one('mouseup', function (e) {
          doc.off('mousemove', pageScroller);
          el.css('cursor', 'auto');
          return false;
        });
        return false;
      }
    });


    function current(x, y) {
      var windowOffset = [window.pageXOffset || document.documentElement.scrollLeft||document.body.scrollLeft,
                 window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop],
          offset = [windowOffset[0] + (prevPos[0] - x), windowOffset[1] + (prevPos[1] - y)];
      prevPos[0] = x; prevPos[1] = y;
      return offset;
    }
  }
})(jQuery);
