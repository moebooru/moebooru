$ = jQuery

class Moe2.CheckAll
  constructor: ->
    $(document).on "click", ".js-check_all", @_checkAll


  _checkAll: (e) =>
    e.preventDefault()

    @_target e.currentTarget.getAttribute("data-target")
      .attr("checked", true)


  _target: (name) =>
    $(".js-check_all-target[data-target='#{name}']")
