export numberToHumanSize = (size, precision) ->
  precision ?= 1
  text = undefined
  size = Number(size)
  if size.toFixed(0) == '1'
    text = '1 Byte'
  else if size < 1024
    text = size.toFixed(0) + ' Bytes'
  else if size < 1024 * 1024
    text = (size / 1024).toFixed(precision) + ' KB'
  else if size < 1024 * 1024 * 1024
    text = (size / (1024 * 1024)).toFixed(precision) + ' MB'
  else if size < 1024 * 1024 * 1024 * 1024
    text = (size / (1024 * 1024 * 1024)).toFixed(precision) + ' GB'
  else
    text = (size / (1024 * 1024 * 1024 * 1024)).toFixed(precision) + ' TB'

  text.gsub(/([0-9]\.\d*?)0+ /, '#{1} ').gsub(/\. /, ' ')
