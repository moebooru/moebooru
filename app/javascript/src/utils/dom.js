export function escapeHtml (str) {
  return str.replace(/[&<>"']/g, function (str) {
    return {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#39;'
    }[str];
  });
}

export function hideEl (el) {
  el.style.display = 'none';
}

export function isVisible (el) {
  const rect = el.getBoundingClientRect();

  return rect.x !== 0 || rect.y !== 0 || rect.width !== 0 || rect.height !== 0;
}

export function showEl (el) {
  el.style.display = '';
}

export function stringToDom (str) {
  const container = document.createElement('div');
  container.innerHTML = str;

  return container.firstChild;
}
