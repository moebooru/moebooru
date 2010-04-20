module FavoriteHelper
  def favorite_list(post)
    html = ""
    
    users = post.favorited_by

    if users.empty?
      html << "no one"
    else
      html << users.slice(0, 6).map {|user| link_to(ERB::Util.h(user.pretty_name), :controller => "user", :action => "show", :id => user.id)}.join(", ")

      if users.size > 6
        html << content_tag("span", :id => "remaining-favs", :style => "display: none;") do
          ", " + users.slice(6..-1).map {|user| link_to(ERB::Util.h(user.pretty_name), {:controller => "user", :action => "show", :id => user.id})}.join(", ")
        end
        html << content_tag("span", :id => "remaining-favs-link") do
          " (" + link_to_function("#{users.size - 6} more", "$('remaining-favs').show(); $('remaining-favs-link').hide()") + ")"
        end
      end
    end

    return html
  end
end
