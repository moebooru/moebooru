export removeImageElement = (image) ->
  return unless image?

  image.src = Vars.blankImage
  # TODO: change to native .remove() once PrototypeJS is removed
  image.parentNode.removeChild image if image.parentNode?

  null
