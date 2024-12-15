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
  let unit;
  if (size.toFixed(0) === '1') {
    precision = 0;
    unit = 'Byte';
  } else if (size < 1024) {
    precision = 0;
    unit = 'Bytes';
  } else if ((size /= 1024) < 1024) {
    unit = 'KB';
  } else if ((size /= 1024) < 1024) {
    unit = 'MB';
  } else if ((size /= 1024) < 1024) {
    unit = 'GB';
  } else {
    size /= 1024;
    unit = 'TB';
  }

  return `${size.toLocaleString(undefined, { maximumFractionDigits: precision })} ${unit}`;
}
