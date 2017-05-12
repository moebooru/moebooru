module TagHelper
  def tag_link(name, options = {})
    name ||= "UNKNOWN"
    prefix = options[:prefix] || ""
    obsolete = options[:obsolete] || []

    tag_type = Tag.type_name(name)
    obsolete_tag = ([name] & obsolete).empty? ? "" : "obsolete"
    html = if prefix.blank?
             "".html_safe
           else
             content_tag(:span, prefix, :class => "#{obsolete_tag}")
    end
    html << content_tag(:span, :class => "tag-type-#{tag_type} #{obsolete_tag}") do
      link_to(name, :controller => :post, :action => :index, :tags => name)
    end
  end

  def tag_links(tags, options = {})
    return "" if tags.blank?

    html = ""

    count_sorting = controller.action_name == "index"
    tags = Tag.sort_by_type(tags, count_sorting)

    tags.each do |tag_type, name, count, _id|
      name ||= "UNKNOWN"

      html << %(<li class="tag-type-#{html_escape(tag_type)}">)

      if CONFIG["enable_artists"] && tag_type == "artist"
        html << %(<a href="/artist/show?name=#{u(name)}">?</a> )
      else
        html << %(<a href="/wiki/show?title=#{u(name)}">?</a> )
      end

      if @current_user.is_privileged_or_higher?
        html << link_to("+", { :controller => "/post", :action => :index, :tags => "#{name} #{params[:tags]}" }, :class => "no-browser-link") << " "
        html << link_to("&ndash;".html_safe, { :controller => "/post", :action => :index, :tags => "-#{name} #{params[:tags]}" }, :class => "no-browser-link") << " "
      end

      tag_link_options = {}
      if options[:with_hover_highlight]
        tag_link_options[:mouseover] = "Post.highlight_posts_with_tag('#{escape_javascript(name)}')"
        tag_link_options[:mouseout] = "Post.highlight_posts_with_tag(null)"
      end
      html << link_to(name.tr("_", " "), { :controller => "/post", :action => :index, :tags => name }, :onmouseover => tag_link_options[:mouseover], :onmouseout => tag_link_options[:mouseout]) << " "
      html << %(<span class="post-count">#{count}</span> )
      html << "</li>"
    end

    if options[:with_aliases]
      # Map tags to aliases to the tag, and include the original tag so search engines can
      # find it.
      id_list = tags.map { |t| t[3] }
      alternate_tags = TagAlias.where(:alias_id => id_list).pluck(:name)
      unless alternate_tags.empty?
        html << %(<span style="display: none;">#{alternate_tags.map { |t| t.tr("_", " ") }.join(" ")}</span>)
      end
    end

    html.html_safe
  end

  def tag_string(tags)
    Tag.sort_by_type(tags).map do |tag|
      tag[1]
    end.join ' '
  end

  def cloud_view(tags, divisor = 6)
    html = "".html_safe

    tags.sort { |a, b| a["name"] <=> b["name"] }.each do |tag|
      size = Math.log(tag["post_count"].to_i) / divisor
      size = size < 0.8 ? "0.8" : "%.1f" % size
      html << link_to(tag["name"], { :controller => :post, :action => :index, :tags => tag["name"] }, :style => "font-size: #{size}em", :title => "#{tag["post_count"]} posts")
    end

    html.html_safe
  end

  def related_tags(tags)
    if tags.blank?
      return ""
    end

    all = []
    pattern, related = tags.split(/\s+/).partition { |i| i.include?("*") }
    pattern.each { |i| all += Tag.where("name LIKE ?", i.to_escaped_for_sql_like).pluck(:name) }
    if related.any?
      Tag.where(:name => TagAlias.to_aliased(related)).find_each { |i| all += i.related.map { |j| j[0] } }
    end
    all.join(" ")
  end
end
