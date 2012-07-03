Favorite = {
  link_to_users: function(users) {
    var html = ""

    if (users.size() == 0) {
      return "no one"
    } else {
       html = users.slice(0, 6).map(function(x) {return '<a href="/user/show/' + x.id + '">' + x.name + '</a>'}).join(", ")

      if (users.size() > 6) {
        html += '<span id="remaining-favs" style="display: none;">' + users.slice(6, -1).map(function(x) {return '<a href="/user/show/' + x.id + '+order%3Avote">' + x.name + '</a>'}).join(", ") + '</span> <span id="remaining-favs-link">(<a href="#" onclick="$(\'remaining-favs\').show(); $(\'remaining-favs-link\').hide(); return false;">' + (users.size() - 6) + ' more</a>)</span>'
      }

      return html
    }
  }
}
