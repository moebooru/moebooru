// Convert dimensions scaled to an image back to the source resolution.
export function frameDimensionsFromImage (frame, image, post) {
  const targetScale = post.width / image.width;
  const scale = (source) => Math.round(source * targetScale);

  return {
    source_top: scale(frame.top),
    source_left: scale(frame.left),
    source_width: scale(frame.width),
    source_height: scale(frame.height)
  };
}

// Given a frame, its post and an image, return the frame's rectangle scaled to
// the size of the image.
export function frameDimensionsToImage (frame, image, post) {
  const targetScale = image.width / post.width;
  const scale = (source) => Math.round(source * targetScale);

  return {
    top: scale(frame.source_top),
    left: scale(frame.source_left),
    width: scale(frame.source_width),
    height: scale(frame.source_height)
  };
}
