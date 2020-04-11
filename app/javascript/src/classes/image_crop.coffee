$ = jQuery

import Cropper from 'cropperjs'

convertCropperToForm = (cropper) ->
  rect = cropper.getCanvasData()
  cropperData = cropper.getData()

  formParsed =
    left: cropperData.x / rect.width
    right: (cropperData.x + cropperData.width) / rect.width
    top: cropperData.y / rect.height
    bottom: (cropperData.y + cropperData.height) / rect.height

  form = {}
  for own coord, value of formParsed
    form[coord] = value.toFixed(4)

  form


convertFormToCropper = (cropper, form) ->
  rect = cropper.getCanvasData()

  formParsed = {}
  validForm = true
  for own coord, value of form
    parsed = parseFloat(value)
    if parsed == 0
      validForm = false
      break
    else
      formParsed[coord] = parsed

  if validForm
    x: formParsed.left * rect.width
    width: (formParsed.right - formParsed.left) * rect.width
    y: formParsed.top * rect.height
    height: (formParsed.bottom - formParsed.top) * rect.height
  else
    base = Math.min(rect.width, rect.height) / 4

    x: base
    width: base
    y: base
    height: base


export default class ImageCrop
  constructor: ->
    $ @initialize


  # to allow submitting the form by pressing enter
  focusSubmit: =>
    @submit?.focus(preventScroll: true)


  initialize: =>
    @form = document.querySelector('.js-image-crop')

    return unless @form?

    @image = @form.querySelector('.js-image-crop--image')
    @preview = @form.querySelector('.js-image-crop--preview')
    @submit = @form.querySelector('input[type="submit"]')

    options =
      preview: @preview
      zoomable: false
      movable: false
      rotatable: false
      scalable: false
    @image.addEventListener('cropend', @onCropend)
    @image.addEventListener('ready', @onReady)
    @cropper = new Cropper(@image, options)

    if @preview?
      @previewContainer = document.querySelector('.js-image-crop--preview-container')
      $(window).on 'resize scroll', @onWindowChange
      @positionPreview()

    @focusSubmit()


  onCropend: (e) =>
    for own coord, value of convertCropperToForm(@cropper)
      @form.querySelector("##{coord}").value = value

    @focusSubmit()


  onReady: =>
    form = {}
    for coord in ['left', 'right', 'top', 'bottom']
      form[coord] = @form.querySelector("##{coord}").value

    @cropper.setData convertFormToCropper(@cropper, form)


  onWindowChange: =>
    requestAnimationFrame(@positionPreview)


  positionPreview: =>
    previewRect = @previewContainer.getBoundingClientRect()
    imageRect = @form.getBoundingClientRect()
    maxRight = document.body.clientWidth

    # try to position it outside the image
    left = imageRect.right + 10
    right = left + previewRect.width

    # if it overflows, keep it inside the window but never outside the image itself
    if right > maxRight
      left = Math.min(imageRect.right, maxRight) - previewRect.width - 10

    # stick to the top when scrolled down
    top = Math.max(0, imageRect.top) + 10

    @previewContainer.style.left = "#{left}px"
    @previewContainer.style.top = "#{top}px"
