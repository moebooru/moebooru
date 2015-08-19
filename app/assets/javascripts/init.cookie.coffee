jQuery(document).ready ($) ->
  # Check if there's new dmail.
  if Cookies('has_mail') == '1'
    $('#has-mail-notice').show()
  # Check if there's new comment.
  if Cookies('comments_updated') == '1'
    $('#comments-link').addClass 'comments-update'
    $('#comments-link').addClass 'bolded'
  # Show block/ban reason if the user is blocked/banned.
  if Cookies('block_reason') and Cookies('block_reason') != ''
    $('#block-reason').text(Cookies('block_reason')).show()
  # Check if there's any pending post moderation queue.
  if parseInt(Cookies('mod_pending')) > 0
    $('#moderate').addClass 'mod-pending'
  return
