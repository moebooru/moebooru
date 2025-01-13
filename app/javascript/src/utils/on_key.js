const keysDown = new Map();

// Many browsers eat keyup events if focus is lost while the button
// is pressed.
document.addEventListener('blur', function () {
  keysDown.clear();
});

export function onKey (key, options, press, release) {
  options ??= {};
  const element = options.Element ?? document;

  element.addEventListener('keyup', function (e) {
    if (e.keyCode !== key) return;
    keysDown.set(e.keyCode, false);
    release?.(e);
  });

  element.addEventListener('keydown', function (e) {
    if (e.keyCode !== key) return;
    if (e.metaKey) return;
    if (e.shiftKey !== !!options.shiftKey) return;
    if (e.altKey !== !!options.altKey) return;
    if (e.ctrlKey !== !!options.ctrlKey) return;
    if (!options.allowRepeat && keysDown.get(e.keyCode)) return;

    keysDown.set(e.keyCode, true);
    if (!options.AllowTextAreaFields && e.target.tagName === 'TEXTAREA') return;
    if (!options.AllowInputFields && e.target.tagName === 'INPUT') return;
    if (press != null && press(e) === false) return;

    e.preventDefault();
  });
}
