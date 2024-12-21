###
# Save the URL hash to local DOM storage when it changes.  When called, restores the
# previously saved hash.
#
# This is used on the iPhone only, and only when operating in web app mode (window.standalone).
# The iPhone doesn't update the URL hash saved in the web app shortcut, nor does it
# remember the current URL when using make-believe multitasking, which means every time
# you switch out and back in you end up back to wherever you were when you first created
# the web app shortcut.  Saving the URL hash allows switching out and back in without losing
# your place.
#
# This should only be used in environments where it's been tested and makes sense.  If used
# in a browser, or in a web app environment that properly tracks the URL hash, this will
# just interfere with normal operation.
###

MaintainUrlHash = ->
  ### When any part of the URL hash changes, save it. ###

  update_stored_hash = (changed_hash_keys, old_hash, new_hash) ->
    hash = localStorage.current_hash = UrlHash.get_raw_hash()
    return

  UrlHash.observe null, update_stored_hash

  ### Restore the previous hash, if any. ###

  hash = localStorage.getItem('current_hash')
  if hash
    UrlHash.set_raw_hash hash
  return
