I18n.defaultLocale = locale.default
I18n.locale = locale.current

I18n.scopify = (scope) ->
  (label, options) ->
    if label[0] == '.'
      label = "#{scope}#{label}"
    I18n.t label, options
