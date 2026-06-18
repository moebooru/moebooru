/* globals Vars */
export function removeImageElement (image) {
  if (image == null) return;

  image.src = Vars.blankImage;
  // TODO: change to native .remove() once PrototypeJS is removed
  if (image.parentNode != null) {
    image.parentNode.removeChild(image);
  }
}
