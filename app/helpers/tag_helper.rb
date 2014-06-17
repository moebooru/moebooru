module TagHelper
  def tag_link(name, options = {})
    name ||= 'UNKNOWN'
    prefix = options[:prefix] || ''
    obsolete = options[:obsolete] || []

    tag_type = Tag.type_name(name)
    obsolete_tag = ([name] & obsolete).empty? ? '' : 'obsolete'
    html = if prefix.blank?
      ''.html_safe
    else
      content_tag(:span, prefix, :class => "#{obsolete_tag}")
    end
    html += content_tag(:span, :class => "tag-type-#{tag_type} #{obsolete_tag}") do
      link_to(name, :controller => :post, :action => :index, :tags => name)
    end
  end

  def tag_links(tags, options = {})
    return "" if tags.blank?
    prefix = options[:prefix] || ""

    html = ""


    case tags[0]
    when String
      tags = Tag.where(:name => tags).select([:name, :post_count, :id, :tag_type]).map { |t| [Tag.type_name_from_value(t.tag_type), t.name, t.post_count, t.id] }

    when Hash, Tag, Array
      case tags[0]
      when Hash
        tags = tags.map {|x| [x["name"], x["post_count"], nil]}
      when Tag
        tags = tags.map {|x| [x.name, x.post_count, x.id]}
      end
      tags_type = Tag.batch_get_tag_types(tags.map { |data| data[0] })
      tags = tags.map { |arr| arr.insert 0, tags_type[arr[0]] }
    end

    case controller.action_name
    when 'show'
      tags.sort_by! { |a| [Tag::TYPE_ORDER[a[0]], a[1]] }
    when 'index'
      tags.sort_by! { |a| [Tag::TYPE_ORDER[a[0]], -a[2].to_i, a[1]] }
    end

    tags.each do |tag_type, name, count, id|
      name ||= "UNKNOWN"

      html << %{<li class="tag-link tag-type-#{html_escape(tag_type)}" data-name="#{html_escape(name)}" data-type="#{html_escape(tag_type)}">}

      if CONFIG["enable_artists"] && tag_type == "artist"
        html << %{<a href="/artist/show?name=#{u(name)}">?</a> }
      else
        html << %{<a href="/wiki/show?title=#{u(name)}">?</a> }
      end

      if @current_user.is_privileged_or_higher?
        html << link_to('+', { :controller => '/post', :action => :index, :tags => "#{name} #{params[:tags]}" }, :class => 'no-browser-link') << ' '
        html << link_to('&ndash;'.html_safe, { :controller => '/post', :action => :index, :tags => "-#{name} #{params[:tags]}" }, :class => 'no-browser-link') << ' '
      end

      tag_link_options = {}
      if options[:with_hover_highlight] then
        tag_link_options[:mouseover] = "Post.highlight_posts_with_tag('#{escape_javascript(name)}')"
        tag_link_options[:mouseout] = "Post.highlight_posts_with_tag(null)"
      end
      html << link_to(name.tr('_', ' '), { :controller => '/post', :action => :index, :tags => name }, :onmouseover => tag_link_options[:mouseover], :onmouseout => tag_link_options[:mouseout]) << ' '
      html << %{<span class="post-count">#{count}</span> }
      html << '</li>'
    end

    if options[:with_aliases] then
      # Map tags to aliases to the tag, and include the original tag so search engines can
      # find it.
      id_list = tags.map { |t| t[3] }
      alternate_tags = TagAlias.where(:alias_id => id_list).pluck(:name)
      if not alternate_tags.empty?
        html << %{<span style="display: none;">#{alternate_tags.map { |t| t.tr("_", " ") }.join(" ")}</span>}
      end
    end

    return html.html_safe
  end

  def cloud_view(tags, divisor = 6)
    html = ''.html_safe

    tags.sort {|a, b| a['name'] <=> b['name']}.each do |tag|
      size = Math.log(tag['post_count'].to_i) / divisor
      size = size < 0.8 ? '0.8' : '%.1f' % size
      html << link_to(tag['name'], { :controller => :post, :action => :index, :tags => tag['name'] }, { :style => "font-size: #{size}em", :title => "#{tag['post_count']} posts" })
    end

    return html.html_safe
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
