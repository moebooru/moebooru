module AvatarHelper
  # id is an identifier for the object referencing this avatar; it's passed down
  # to the javascripts to implement blacklisting "click again to open".
  def avatar(user, id, html_options = {})
    @shown_avatars ||= {}
    @posts_to_send ||= []

    #if not @shown_avatars[user] then
      @shown_avatars[user] = true
      @posts_to_send << user.avatar_post
      img = image_tag(user.avatar_url + "?" + user.avatar_timestamp.tv_sec.to_s,
                      {:class => "avatar", :width => user.avatar_width, :height => user.avatar_height}.merge(html_options))
      link_to(img,
              { :controller => "post", :action => "show", :id => user.avatar_post.id.to_s },
              :class => "ca" + user.avatar_post.id.to_s,
              :onclick => %{return Post.check_avatar_blacklist(#{user.avatar_post.id.to_s}, #{id});})
    #end
  end

  def avatar_init
    return "" if not defined?(@posts_to_send)
    ret = ""
    @posts_to_send.uniq.each do |post|
      ret << %{Post.register(#{ json_escape post.to_json.html_safe })\n}
    end
    ret << %{Post.init_blacklisted()}
    ret.html_safe
  end
end
