export function clamp (n, min, max) {
  return Math.max(Math.min(n, max), min);
}

// Return the squared distance between two points.
export function distanceSquared (x1, y1, x2, y2) {
  return (x1 - x2) ** 2 + (y1 - y2) ** 2;
}

export function numberToHumanSize (size, precision) {
  precision ??= 1;
  size = Number(size);
  let text;
  if (size.toFixed(0) === '1') {
    text = '1 Byte';
  } else if (size < 1024) {
    text = `${size.toFixed(0)} Bytes`;
  } else if (size < 1024 * 1024) {
    text = `${(size / 1024).toFixed(precision)} KB`;
  } else if (size < 1024 * 1024 * 1024) {
    text = `${(size / (1024 * 1024)).toFixed(precision)} MB`;
  } else if (size < 1024 * 1024 * 1024 * 1024) {
    text = `${(size / (1024 * 1024 * 1024)).toFixed(precision)} GB`;
  } else {
    text = `${(size / (1024 * 1024 * 1024 * 1024)).toFixed(precision)} TB`;
  }

  return text.replace(/([0-9]\.\d*?)0+ /, '$1 ').replace('. ', ' ');
}
