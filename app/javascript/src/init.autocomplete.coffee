$ = jQuery

$ ->
  $('.ac-user-name').autocomplete
    source: Vars.path.ac_user_name
    minLength: 2

  $('.ac-tag-name').autocomplete
    source: Vars.path.ac_tag_name
    minLength: 2

  editForm = $('#edit-form')[0]
  acTags = $('.ac-tags')[0]

  if editForm? && acTags?
    new TagCompletionBox(acTags)

    if TagCompletion
      TagCompletion.observe_tag_changes_on_submit editForm, acTags
