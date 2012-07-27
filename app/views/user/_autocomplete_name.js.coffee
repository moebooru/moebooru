jQuery(document).ready ($) ->
  $('#<%= field_id %>').autocomplete
    source: '<%= escape_javascript ac_user_name_path %>'
    minLength: 2
