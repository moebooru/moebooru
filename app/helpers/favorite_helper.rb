module FavoriteHelper
  def favorite_list(post)
    html = "".html_safe

    users = post.favorited_by
    users_link = users.map { |user| link_to user.pretty_name, :controller => :user, :action => :show, :id => user.id  }

    if users.empty?
      html << "no one"
    else
      html << users_link.first(6).join(", ").html_safe

      if users.size > 6
        html << content_tag(:span, :id => "remaining-favs", :style => "display: none;") do
          ", #{users_link.slice(6..-1).join(", ")}".html_safe
        end
        html << content_tag(:span, :id => "remaining-favs-link") do
          " (#{link_to "#{users.size - 6} more", '#'})".html_safe
        end
      end
    end

    html.html_safe
  end
end
