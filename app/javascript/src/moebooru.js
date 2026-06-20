/* globals jQuery, Vars */
const $ = jQuery;
window.Moebooru = {};
window.Moe = $(window.Moebooru);

window.Moebooru.path = (url) => (
  Vars.prefix === '/' ? url : `${Vars.prefix}${url}`
);

// XXX: Tested on chrome, mozilla, msie(9/10)
// might or might not work in other browser
window.Moebooru.dragElement = (el) => {
  const doc = $(document);
  let prevPos = [];

  function current (x, y) {
    const windowOffset = [
      window.pageXOffset || document.documentElement.scrollLeft || document.body.scrollLeft,
      window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop
    ];
    const offset = [
      windowOffset[0] + prevPos[0] - x,
      windowOffset[1] + prevPos[1] - y
    ];

    prevPos[0] = x;
    prevPos[1] = y;

    return offset;
  }

  el.on('dragstart', () => {
    return false;
  });

  el.on('mousedown', (e) => {
    if (e.which !== 1) return;

    const pageScroller = (e) => {
      window.scrollTo(...current(e.clientX, e.clientY));
      el.attr('data-drag-element', '1');
      return false;
    };

    el.css('cursor', 'pointer');
    prevPos = [e.clientX, e.clientY];

    doc.on('mousemove', pageScroller);

    doc.one('mouseup', (e) => {
      doc.off('mousemove', pageScroller);
      setTimeout(() => {
        el.removeAttr('data-drag-element');
      }, 0);
      el.css('cursor', 'auto');
      return false;
    });

    return false;
  });
};
