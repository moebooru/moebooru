window.InitTextAreas = ->
  for elem in document.querySelectorAll('form textarea')
    continue if elem.dataset.setAutoSubmitHandler == '1'

    elem.dataset.setAutoSubmitHandler = '1'
    form = elem.closest('form')
    OnKey 13, {
      ctrlKey: true
      AllowInputFields: true
      AllowTextAreaFields: true
      Element: elem
    }, -> form.requestSubmit()
