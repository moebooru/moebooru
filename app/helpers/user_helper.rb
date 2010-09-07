module UserHelper
  def favorite_tag_listing(user)
    html = []
    user.favorite_tags.each do |favtag|
      html << '<p><strong>' + h(favtag.name) + '</strong>: '
      tags = favtag.tag_query.scan(/\S+/).sort
      group = []
      tags.each do |tag|
        group << link_to(h(tag), :controller => "post", :action => "index", :tags => tag)
      end
      html[-1] << group.join(" ") + '</p>'
    end
    html.join("\n")
  end
end
