import { onKey } from './on_key';

export function initTextAreas () {
  for (const elem of document.querySelectorAll('form textarea')) {
    if (elem.dataset.setAutoSubmitHandler === '1') {
      continue;
    }

    elem.dataset.setAutoSubmitHandler = '1';
    const form = elem.closest('form');
    onKey(13, {
      ctrlKey: true,
      AllowInputFields: true,
      AllowTextAreaFields: true,
      Element: elem
    }, function () {
      form.requestSubmit();
    });
  }
}
