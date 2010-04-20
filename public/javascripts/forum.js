Forum = {
  mark_all_read: function() {
    new Ajax.Request("/forum/mark_all_read", {
      onComplete: function() {
        $$("span.forum-topic").invoke("removeClassName", "unread-topic")
        notice("Marked all topics as read")
      }
    })
  },
  quote: function(id) {
    new Ajax.Request("/forum/show.json", {
      method: 'get',
      parameters: {
        "id": id
      },
      onSuccess: function(resp) {
        var resp = resp.responseJSON
        $('reply').show()
        var stripped_body = resp.body.replace(/\[quote\](?:.|\n|\r)+?\[\/quote\][\n\r]*/gm, "")
        $('forum_post_body').value += '[quote]' + resp.creator + ' said:\n' + stripped_body + '\n[/quote]\n\n'
				$("respond-link").hide()
				$("forum_post_body").focus()
      },
      onFailure: function(req) {
        notice("Error quoting forum post")
      }
    })
  }
}
