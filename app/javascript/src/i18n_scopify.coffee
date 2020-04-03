do ->

  I18n.scopify = (scope) ->
    (label, options) ->
      if label.charAt(0) == '.'
        label = scope + label
      I18n.t label, options

  return
