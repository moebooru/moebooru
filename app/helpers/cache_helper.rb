module CacheHelper
  def build_cache_key(base, tags, page, limit, options = {})
    page = page.to_i
    page = 1 if page < 1
    tags = tags.to_s.downcase.split.sort

    if options[:user]
      user_level = options[:user].level
      user_level = CONFIG["user_levels"]["Member"] if user_level < CONFIG["user_levels"]["Member"]
    else
      user_level = "?"
    end

    version = Moebooru::CacheHelper.get_version
    tags = tags.join(" ")

    key = {}
    key[:base] = base
    key[:version] = version
    key[:tags] = tags
    key[:page] = page
    key[:user_level] = user_level
    key[:limit] = limit
    [key, 0]
  end

  def get_cache_key(controller_name, action_name, params, options = {})
    case "#{controller_name}/#{action_name}"
    when "post/index"
      build_cache_key("p/i", params[:tags], page_number, params[:limit], options)
    when "post/atom"
      build_cache_key("p/a", params[:tags], 1, "", options)
    when "post/piclens"
      build_cache_key("p/p", params[:tags], page_number, params[:limit], options)
    end
  end
end
