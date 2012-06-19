module TagHelper
  def tag_link(tag)
    tag_type = Tag.type_name(tag)
    html = %{<span class="tag-type-#{tag_type}">}
    html << link_to(h(tag), :action => "index", :tags => tag)
    html << %{</span>}
  end

  def tag_links(tags, options = {})
    return "" if tags.blank?
    prefix = options[:prefix] || ""

    html = ""

    case tags[0]
    when String
      tags = Tag.find(:all, :conditions => ["name in (?)", tags], :select => "name, post_count, id").inject({}) {|all, x| all[x.name] = [x.post_count, x.id]; all}.sort {|a, b| a[0] <=> b[0]}.map { |a| [a[0], a[1][0], a[1][1]] }

    when Hash
      tags = tags.map {|x| [x["name"], x["post_count"], nil]}

    when Tag
      tags = tags.map {|x| [x.name, x.post_count, x.id]}
    end

    tags.each do |name, count, id|
      name ||= "UNKNOWN"

      tag_type = Tag.type_name(name)

      html << %{<li class="tag-type-#{tag_type}">}

      if CONFIG["enable_artists"] && tag_type == "artist"
        html << %{<a href="/artist/show?name=#{u(name)}">?</a> }
      else
        html << %{<a href="/wiki/show?title=#{u(name)}">?</a> }
      end

      if @current_user.is_privileged_or_higher?
        html << %{<a href="/post/index?tags=#{u(name)}+#{u(params[:tags])}" class="no-browser-link">+</a> }
        html << %{<a href="/post/index?tags=-#{u(name)}+#{u(params[:tags])}" class="no-browser-link">&ndash;</a> }
      end

      if options[:with_hover_highlight] then
        mouseover=%{ onmouseover='Post.highlight_posts_with_tag("#{escape_javascript(name).gsub("'", "&#145;")}")'}
        mouseout=%{ onmouseout='Post.highlight_posts_with_tag(null)'}
      end
      html << %{<a href="/post/index?tags=#{u(name)}"#{mouseover}#{mouseout}>#{h(name.tr("_", " "))}</a> }
      html << %{<span class="post-count">#{count}</span> }
      html << '</li>'
    end

    if options[:with_aliases] then
      # Map tags to aliases to the tag, and include the original tag so search engines can
      # find it.
      id_list = tags.map { |t| t[2] }
      alternate_tags = TagAlias.find(:all, :select => :name, :conditions => ["alias_id IN (?)", id_list]).map { |t| t.name }.uniq
      if not alternate_tags.empty?
        html << %{<span style="display: none;">#{alternate_tags.map { |t| t.tr("_", " ") }.join(" ")}</span>}
      end
    end

    return html
  end

  def cloud_view(tags, divisor = 6)
    html = ""

    tags.sort {|a, b| a["name"] <=> b["name"]}.each do |tag|
      size = Math.log(tag["post_count"].to_i) / divisor
      size = 0.8 if size < 0.8
      html << %{<a href="/post/index?tags=#{u(tag["name"])}" style="font-size: #{size}em;" title="#{tag["post_count"]} posts">#{h(tag["name"])}</a> }
    end

    return html
  end

  def related_tags(tags)
    if tags.blank?
      return ""
    end

    all = []
    pattern, related = tags.split(/\s+/).partition {|i| i.include?("*")}
    pattern.each {|i| all += Tag.find(:all, :conditions => ["name LIKE ?", i.tr("*", "%")]).map {|j| j.name}}
    if related.any?
      Tag.find(:all, :conditions => ["name IN (?)", TagAlias.to_aliased(related)]).each {|i| all += i.related.map {|j| j[0]}}
    end
    all.join(" ")
  end
end
