jQuery(document).ready ($) ->
  $('#post_tags').val $.map($('li.tag-link'), (t, _) ->
    $(t).data 'name'
  ).join(' ')
  return
