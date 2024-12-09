import { applyDrag, createDragBox } from 'src/utils/drag_box'
import { frameDimensionsFromImage, frameDimensionsToImage } from 'src/utils/frame_math'

# Create the specified corner dragger.
export default class CornerDragger
  constructor: (@container, @part, @options) ->
    box = @container.querySelector('.frame-editor-popup-div')

    # Create a div inside each .frame-editor-popup-div floating on top of the image
    # to show the border of the frame.
    frameBox = document.createElement('div')
    frameBox.className = 'frame-editor-frame-box'
    createDragBox frameBox
    box.appendChild frameBox

    dragElementOptions =
      snap_pixels: 0
      ondown: (e) =>
        element = document.elementFromPoint(e.x, e.y)

        # If we clicked on a drag handle, use that handle.  Otherwise, choose the corner drag
        # handle for the corner we're in.
        if element.classList.contains('frame-box-handle')
          @dragging_mode = element._frameDragCursor
        else if @part == '.frame-editor-nw'
          @dragging_mode = 'nw-resize'
        else if @part == '.frame-editor-ne'
          @dragging_mode = 'ne-resize'
        else if @part == '.frame-editor-sw'
          @dragging_mode = 'sw-resize'
        else if @part == '.frame-editor-se'
          @dragging_mode = 'se-resize'
        post = Post.posts.get(@post_id)
        frame = post.frames_pending[@post_frame]
        @dragging_anchor = frameDimensionsToImage(frame, @image_dimensions, post)

        # When dragging a handle, hide the cursor to get it out of the way.
        @dragger.overriden_drag_class = if @dragging_mode == 'move' then null else 'hide-cursor'

        # Stop propagation of the event, so any other draggers in the chain don't start.  In
        # particular, when we're dragging inside the image, we need to stop WindowDragElementAbsolute.
        # Only do this if we're actually dragging, not if we aborted due to this.drag_to_create.
        e.latest_event.stopPropagation()

        return

      ondrag: (e) =>
        post = Post.posts.get(@post_id)

        # Invert the motion, since we're dragging the image around underneith the
        # crop frame instead of dragging the crop frame around.
        dims = applyDrag(@dragging_mode, -e.aX, -e.aY, @image_dimensions, @dragging_anchor)

        # Scale the changed dimensions back to the source resolution and apply them
        # to the frame.
        source_dims = frameDimensionsFromImage(dims, @image_dimensions, post)
        post.frames_pending[@post_frame] = source_dims
        @options.onUpdate?()

        return

    @dragger = new DragElement(box, dragElementOptions)

    @update()

  # Set the post to show in the corner dragger.  If post_id is null, clear any displayed
  # post.
  #
  # When the post ID is set, the post frame is always cleared.
  set_post_id: (post_id) ->
    @post_id = post_id
    @post_frame = null
    url = null
    img = @container.querySelector('img')
    if post_id?
      post = Post.posts.get(@post_id)
      @image_dimensions =
        width: post.jpeg_width
        height: post.jpeg_height
      url = post.jpeg_url
      img.width = @image_dimensions.width
      img.height = @image_dimensions.height

    # Don't change the image if it's already set; it causes Chrome to reprocess
    # the image.
    if img.src != url
      img.src = url ? Vars.blankImage
      if url?
        # Decoding in Chrome takes long enough to be visible.  Hourglass the cursor while it runs.
        document.documentElement.classList.add 'hourglass'
        window.setTimeout ->
          document.documentElement.classList.remove 'hourglass'

    @update()

    return


  set_post_frame: (post_frame) ->
    @post_frame = post_frame
    @update()

    return


  update: ->
    return if !@post_id? || !@post_frame?

    post = Post.posts.get(@post_id)
    frame = post.frames_pending[@post_frame]
    dims = frameDimensionsToImage(frame, @image_dimensions, post)
    div = @container

    # Update the drag/frame box.
    box = @container.querySelector('.frame-editor-frame-box')
    box.style.left = dims.left + 'px'
    box.style.top = dims.top + 'px'
    box.style.width = dims.width + 'px'
    box.style.height = dims.height + 'px'

    # Recenter the corner box.
    top = dims.top
    left = dims.left
    if @part == '.frame-editor-ne' or @part == '.frame-editor-se'
      left += dims.width
    if @part == '.frame-editor-sw' or @part == '.frame-editor-se'
      top += dims.height
    offset_height = div.offsetHeight / 2
    offset_width = div.offsetWidth / 2

    ###
    if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-ne") offset_height -= div.offsetHeight/4;
    if(this.part == ".frame-editor-sw" || this.part == ".frame-editor-se") offset_height += div.offsetHeight/4;
    if(this.part == ".frame-editor-nw" || this.part == ".frame-editor-sw") offset_width -= div.offsetWidth/4;
    if(this.part == ".frame-editor-ne" || this.part == ".frame-editor-se") offset_width += div.offsetWidth/4;
    ###

    left -= offset_width
    top -= offset_height

    # If the region is small enough that we don't have enough to fill the corner
    # frames, push the frames inward so they line up. 
    if @part == '.frame-editor-nw' or @part == '.frame-editor-sw'
      left = Math.min(left, dims.left + dims.width / 2 - (div.offsetWidth))
    if @part == '.frame-editor-ne' or @part == '.frame-editor-se'
      left = Math.max(left, dims.left + dims.width / 2)
    if @part == '.frame-editor-nw' or @part == '.frame-editor-ne'
      top = Math.min(top, dims.top + dims.height / 2 - (div.offsetHeight))
    if @part == '.frame-editor-sw' or @part == '.frame-editor-se'
      top = Math.max(top, dims.top + dims.height / 2)
    img = @container.querySelector('.frame-editor-popup-div')
    img.style.marginTop = -top + 'px'
    img.style.marginLeft = -left + 'px'

    return
