# Convert dimensions scaled to an image back to the source resolution.
export frameDimensionsFromImage = (frame, image, post) ->
  targetScale = post.width / image.width
  scale = (source) -> Math.round(source * targetScale)

  source_top: scale frame.top
  source_left: scale frame.left
  source_width: scale frame.width
  source_height: scale frame.height


# Given a frame, its post and an image, return the frame's rectangle scaled to
# the size of the image.
export frameDimensionsToImage = (frame, image, post) ->
  targetScale = image.width / post.width
  scale = (source) -> Math.round(source * targetScale)

  top: scale frame.source_top
  left: scale frame.source_left
  width: scale frame.source_width
  height: scale frame.source_height
