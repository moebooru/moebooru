module CacheHelper
  def build_cache_key(base, tags, page, limit, options = {})
    page = page.to_i
    page = 1 if page < 1
    tags = tags.to_s.downcase.scan(/\S+/).sort

    if options[:user]
      user_level = options[:user].level
      user_level = CONFIG["user_levels"]["Member"] if user_level < CONFIG["user_levels"]["Member"]
    else
      user_level = "?"
    end

    if tags.empty? || tags.any? {|x| x =~ /(?:^-|[*:])/}
      version = Rails.cache.read("$cache_version").to_i
      tags = tags.join(",")
    else
      version = "?"
      tags = tags.map {|x| x + ":" + Rails.cache.read("tag:#{x}").to_i.to_s}.join(",")
    end
    tags = Base64.urlsafe_encode64(tags)

    ["#{base}/v=#{version}&t=#{tags}&p=#{page}&ul=#{user_level}&l=#{limit}", 0]
  end

  def get_cache_key(controller_name, action_name, params, options = {})
    case "#{controller_name}/#{action_name}"
    when "post/index"
      build_cache_key("p/i", params[:tags], params[:page], params[:limit], options)

    when "post/atom"
      build_cache_key("p/a", params[:tags], 1, "", options)

    when "post/piclens"
      build_cache_key("p/p", params[:tags], params[:page], params[:limit], options)

    else
      nil
    end
  end
end
