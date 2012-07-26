jQuery(document).ready ($) ->
  $('#tag_name').autocomplete({
    source: '<%= escape_javascript ac_tag_name_path.to_s %>'
    minLength: 2
  })
