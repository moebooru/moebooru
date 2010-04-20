Dmail = {
  respond: function(to) {
    $("dmail_to_name").value = to
    var stripped_body = $("dmail_body").value.replace(/\[quote\](?:.|\n)+?\[\/quote\]\n*/gm, "")
    $("dmail_body").value = "[quote]You said:\n" + stripped_body + "\n[/quote]\n\n"
    $("response").show()
  },

  expand: function(parent_id, id) {
    notice("Fetching previous messages...")
    
    new Ajax.Updater('previous-messages', '/dmail/show_previous_messages', {
      method: 'get',
      parameters: {
        "id": id,
        "parent_id": parent_id
      },
      onComplete: function() {
        $('previous-messages').show()
        notice("Previous messages loaded")
      }
    })
  }
}
