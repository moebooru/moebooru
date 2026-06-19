/* globals I18n, locale */
function scopify (scope) {
  return function (label, options) {
    if (label[0] === '.') {
      label = `${scope}${label}`;
    }

    return I18n.t(label, options);
  };
}

I18n.defaultLocale = locale.default;
I18n.locale = locale.current;
I18n.scopify = scopify;
