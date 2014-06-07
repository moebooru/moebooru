jQuery(document).ready(function($) {
  $(".js-user-record-destroy").click(function(e) {
    e.preventDefault()
    UserRecord.destroy($(e.target).data("id"))
  })
})
