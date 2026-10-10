import { removeImageElement } from 'src/utils/image';

function onImageCompleteEvent (event) {
  // TODO: change to native .remove() once PrototypeJS is removed
  const element = event.target;
  if (element.parentNode != null) {
    element.remove();
  }
}

export default class PreloadContainer {
  constructor () {
    this.container = document.createElement('div');
    this.container.style.display = 'none';
    document.body.appendChild(this.container);
  }

  cancelPreload (img) {
    removeImageElement(img);
  }

  destroy = () => {
    this.container.remove();
  };

  getAll = () => {
    return this.container.children;
  };

  preload = (url) => {
    const img = document.createElement('img');
    img.addEventListener('load', onImageCompleteEvent);
    img.addEventListener('error', onImageCompleteEvent);
    img.src = url;
    this.container.appendChild(img);

    return img;
  };
}
