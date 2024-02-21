export escapeHtml = (str) -> str.replace(/[&<>"']/g, (str) => ({
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
})[str])

export hideEl = (el) -> el.style.display = 'none'

export showEl = (el) -> el.style.display = ''
