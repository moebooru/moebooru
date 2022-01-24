export default class PreloadContainer
  constructor: ->
    @container = document.createElement('div')
    @container.style.display = 'none'
    document.body.appendChild @container


  cancelPreload: (img) =>
    img.remove()


  destroy: =>
    @container.remove()


  getAll: =>
    @container.children


  onImageCompleteEvent: (event) =>
    # TODO: change to native .remove() once PrototypeJS is removed
    element = event.target
    element.remove() if element.parentNode?


  preload: (url) =>
    img = document.createElement('img')
    img.addEventListener 'load', @onImageCompleteEvent
    img.addEventListener 'error', @onImageCompleteEvent
    img.src = url
    @container.appendChild img

    img
