import { clamp } from './math'

export applyDrag = (dragging_mode, x, y, image_dimensions, box) ->
  move_modes =
    'move':
      left: +1
      top: +1
      bottom: +1
      right: +1
    'n-resize': top: +1
    's-resize': bottom: +1
    'w-resize': left: +1
    'e-resize': right: +1
    'nw-resize':
      top: +1
      left: +1
    'ne-resize':
      top: +1
      right: +1
    'sw-resize':
      bottom: +1
      left: +1
    'se-resize':
      bottom: +1
      right: +1
  mode = move_modes[dragging_mode]
  result =
    left: box.left
    top: box.top
    width: box.width
    height: box.height
  right = result.left + result.width
  bottom = result.top + result.height
  if dragging_mode == 'move'
    # In move mode, clamp the movement.  In other modes, clip the size below.
    x = clamp(x, -result.left, image_dimensions.width - right)
    y = clamp(y, -result.top, image_dimensions.height - bottom)

  # Apply the drag.
  if mode.top?
    result.top += y * mode.top
  if mode.left?
    result.left += x * mode.left
  if mode.right?
    right += x * mode.right
  if mode.bottom?
    bottom += y * mode.bottom
  if dragging_mode != 'move'

    # Only clamp the dimensions that were modified.
    if mode.left?
      result.left = clamp(result.left, 0, right - 1)
    if mode.top?
      result.top = clamp(result.top, 0, bottom - 1)
    if mode.bottom?
      bottom = clamp(bottom, result.top + 1, image_dimensions.height)
    if mode.right?
      right = clamp(right, result.left + 1, image_dimensions.width)
  result.width = right - (result.left)
  result.height = bottom - (result.top)

  result


export createDragBox = (div) ->
  # Create the corner handles after the edge handles, so they're on top.
  createHandle div, 'n-resize',
    top: '-5px'
    width: '100%'
    height: '10px'
  createHandle div, 's-resize',
    bottom: '-5px'
    width: '100%'
    height: '10px'
  createHandle div, 'w-resize',
    left: '-5px'
    height: '100%'
    width: '10px'
  createHandle div, 'e-resize',
    right: '-5px'
    height: '100%'
    width: '10px'
  createHandle div, 'nw-resize',
    top: '-5px'
    left: '-5px'
    height: '10px'
    width: '10px'
  createHandle div, 'ne-resize',
    top: '-5px'
    right: '-5px'
    height: '10px'
    width: '10px'
  createHandle div, 'sw-resize',
    bottom: '-5px'
    left: '-5px'
    height: '10px'
    width: '10px'
  createHandle div, 'se-resize',
    bottom: '-5px'
    right: '-5px'
    height: '10px'
    width: '10px'


createHandle = (div, cursor, style) ->
  handle = document.createElement('div')
  handle._frameDragCursor = cursor
  handle.className = "frame-box-handle #{cursor}"
  handle.style.position = 'absolute'
  handle.style.pointerEvents = 'all'
  for own key, value of style
    handle.style[key] = value

  div.appendChild handle
