export default class ClipRange
  constructor: (@min, @max) ->
    throw 'paramError' if @min > @max


  clip: (x) =>
    if x < @min
      return @min
    if x > @max
      return @max

    x
