export default class ImgPoolHandlerDummy
  get: ->
    $ document.createElement('IMG')


  release: (img) ->
    img.src = Vars.asset['blank.gif']
