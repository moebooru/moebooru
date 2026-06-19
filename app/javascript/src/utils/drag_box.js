import { clamp } from './math';

const moveModes = {
  move: {
    left: 1,
    top: 1,
    bottom: 1,
    right: 1
  },
  'n-resize': {
    top: 1
  },
  's-resize': {
    bottom: 1
  },
  'w-resize': {
    left: 1
  },
  'e-resize': {
    right: 1
  },
  'nw-resize': {
    top: 1,
    left: 1
  },
  'ne-resize': {
    top: 1,
    right: 1
  },
  'sw-resize': {
    bottom: 1,
    left: 1
  },
  'se-resize': {
    bottom: 1,
    right: 1
  }
};

export function applyDrag (draggingMode, x, y, imageDimensions, box) {
  const mode = moveModes[draggingMode];
  const result = {
    left: box.left,
    top: box.top,
    width: box.width,
    height: box.height
  };
  let right = result.left + result.width;
  let bottom = result.top + result.height;
  if (draggingMode === 'move') {
    // In move mode, clamp the movement.  In other modes, clip the size below.
    x = clamp(x, -result.left, imageDimensions.width - right);
    y = clamp(y, -result.top, imageDimensions.height - bottom);
  }

  // Apply the drag.
  result.top += y * (mode.top ?? 0);
  result.left += x * (mode.left ?? 0);
  right += x * (mode.right ?? 0);
  bottom += y * (mode.bottom ?? 0);

  if (draggingMode !== 'move') {
    // Only clamp the dimensions that were modified.
    if (mode.left != null) {
      result.left = clamp(result.left, 0, right - 1);
    }
    if (mode.top != null) {
      result.top = clamp(result.top, 0, bottom - 1);
    }
    if (mode.bottom != null) {
      bottom = clamp(bottom, result.top + 1, imageDimensions.height);
    }
    if (mode.right != null) {
      right = clamp(right, result.left + 1, imageDimensions.width);
    }
  }
  result.width = right - (result.left);
  result.height = bottom - (result.top);

  return result;
}

export function createDragBox (div) {
  // Create the corner handles after the edge handles, so they're on top.
  createHandle(div, 'n-resize', {
    top: '-5px',
    width: '100%',
    height: '10px'
  });
  createHandle(div, 's-resize', {
    bottom: '-5px',
    width: '100%',
    height: '10px'
  });
  createHandle(div, 'w-resize', {
    left: '-5px',
    height: '100%',
    width: '10px'
  });
  createHandle(div, 'e-resize', {
    right: '-5px',
    height: '100%',
    width: '10px'
  });
  createHandle(div, 'nw-resize', {
    top: '-5px',
    left: '-5px',
    height: '10px',
    width: '10px'
  });
  createHandle(div, 'ne-resize', {
    top: '-5px',
    right: '-5px',
    height: '10px',
    width: '10px'
  });
  createHandle(div, 'sw-resize', {
    bottom: '-5px',
    left: '-5px',
    height: '10px',
    width: '10px'
  });
  createHandle(div, 'se-resize', {
    bottom: '-5px',
    right: '-5px',
    height: '10px',
    width: '10px'
  });
}

function createHandle (div, cursor, style) {
  const handle = document.createElement('div');
  handle._frameDragCursor = cursor;
  handle.className = `frame-box-handle ${cursor}`;
  handle.style.position = 'absolute';
  handle.style.pointerEvents = 'all';

  for (const [key, value] of Object.entries(style)) {
    handle.style[key] = value;
  }

  div.appendChild(handle);
}
