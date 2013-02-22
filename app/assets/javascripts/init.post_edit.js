jQuery(document).ready(function($) {
  $('#post_tags').val(
    $.map($('li.tag-link'),
      function(t, _) { return $(t).data('name'); }
    ).join(' ')
  );
});
