module UserHelper
  def user_level_select_tag(name, options = {})
    choices = CONFIG["user_levels"].to_a.sort_by {|x| x[1]}
    choices.unshift ["", ""]
    select_tag(name, options_for_select(choices), options)
  end
end
