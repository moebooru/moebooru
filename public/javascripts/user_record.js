UserRecord = {
  destroy: function(id) {
    notice('Deleting record #' + id)

    new Ajax.Request('/user_record/destroy.json', {
      parameters: {
        "id": id
      },
      onComplete: function(resp) {
        if (resp.status == 200) {
          notice("Record deleted")
        } else {
          notice("Access denied")
        }
      }
    })
  }
}
