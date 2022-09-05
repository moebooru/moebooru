module UserHelper
  def user_level_select_tag(name, options = {})
    choices = CONFIG["user_levels"].to_a.sort_by { |x| x[1] }
    select_tag(name, options_for_select(choices, options.delete(:selected)), options)
  end
end
