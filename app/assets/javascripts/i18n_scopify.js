(function () {
  I18n.scopify = function (scope) {
    return function (label, options) {
      if (label.charAt(0) == '.')
        label = scope + label;
      return I18n.t(label, options);
    }
  };
})();
