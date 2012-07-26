jQuery(document).ready ($) ->
  $('#tag_name').autocomplete({
    source: '<%= escape_javascript ac_tag_name_path %>'
    minLength: 2
  })
