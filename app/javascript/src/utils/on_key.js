var keysDown;

keysDown = new Map();

// Many browsers eat keyup events if focus is lost while the button
// is pressed.
document.addEventListener('blur', function() {
  return keysDown.clear();
});

export var onKey = function(key, options, press, release) {
  var element, ref;
  if (options == null) {
    options = {};
  }
  element = (ref = options.Element) != null ? ref : document;
  element.addEventListener('keyup', function(e) {
    if (e.keyCode !== key) {
      return;
    }
    keysDown.set(e.keyCode, false);
    if (release) {
      release(e);
    }
  });
  return element.addEventListener('keydown', function(e) {
    var target;
    if (e.keyCode !== key) {
      return;
    }
    if (e.metaKey) {
      return;
    }
    if (e.shiftKey !== !!options.shiftKey) {
      return;
    }
    if (e.altKey !== !!options.altKey) {
      return;
    }
    if (e.ctrlKey !== !!options.ctrlKey) {
      return;
    }
    if (!options.allowRepeat && keysDown.get(e.keyCode) === true) {
      return;
    }
    keysDown.set(e.keyCode, true);
    target = e.target;
    if (!options.AllowTextAreaFields && target.tagName === 'TEXTAREA') {
      return;
    }
    if (!options.AllowInputFields && target.tagName === 'INPUT') {
      return;
    }
    if ((press != null) && !press(e)) {
      return;
    }
    return e.preventDefault();
  });
};
