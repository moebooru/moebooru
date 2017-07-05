module PostHelper
  def source_link(source, abbreviate = true)
    if source.empty?
      "none"
    elsif source[/^http/]
      text = source
      text = text[7, 20] + "..." if abbreviate
      link_to text, source, :rel => "nofollow"
    else
      h(source)
    end
  end

  def auto_discovery_link_tag_with_id(type = :rss, url_options = {}, tag_options = {})
    tag(
      "link",
      "rel"   => tag_options[:rel] || "alternate",
      "type"  => tag_options[:type] || "application/#{type}+xml",
      "title" => tag_options[:title] || type.to_s.upcase,
      "id"    => tag_options[:id],
      "href"  => url_options.is_a?(Hash) ? url_for(url_options.merge(:only_path => false)) : url_options
    )
  end

  def print_preview(post, options = {})
    is_post = post.instance_of?(Post)
    if is_post && !CONFIG["can_see_post"].call(@current_user, post)
      return ""
    end

    image_class = "preview"
    image_id = options[:image_id]
    image_id = %(id="#{h(image_id)}") if image_id
    if is_post
      image_title = h("Rating: #{post.pretty_rating} Score: #{post.score} Tags: #{post.cached_tags} User: #{post.author}")
    else
      image_title = ""
    end
    link_onclick = options[:onclick]
    link_onclick = %(onclick="#{link_onclick}") if link_onclick
    link_onmouseover = %(onmouseover="#{options[:onmouseover]}") if options[:onmouseover]
    link_onmouseout = %(onmouseout="#{options[:onmouseout]}") if options[:onmouseout]

    if options[:display] == :block
      # Show the thumbnail at its actual resolution, and crop it with northern orientation
      # to a smaller size.
      width, height = post.raw_preview_dimensions
      block_size = [200, 200]
      visible_width = [block_size[0], width].min
      crop_left = (width - visible_width) / 2
    elsif options[:display] == :large
      width, height = post.raw_preview_dimensions
      block_size = [width, height]
      crop_left = 0
    else
      # Scale it down to a smaller size.  This is exactly one half the actual size, to improve
      # resizing quality.
      width, height = post.preview_dimensions
      block_size = [150, 150]
      crop_left = 0
    end

    image = %(<img src="#{post.preview_url}" style="margin-left: #{-crop_left}px;" alt="#{image_title}" class="#{image_class}" title="#{image_title}" #{image_id} width="#{width}" height="#{height}">)
    if is_post
      plid = %(<span class="plid">#pl #{request.protocol}#{h CONFIG["server_host"]}/post/show/#{post.id}</span>)
      target_url = %(/post/show/#{post.id})
    else
      plid = ""
      target_url = post.url
    end

    link_class = "thumb"
    link_class += " no-browser-link" unless is_post
    link = %(<a class="#{link_class}" href="#{target_url}" #{link_onclick}#{link_onmouseover}#{link_onmouseout}>#{image}#{plid}</a>)
    div = %(<div class="inner" style="width: #{block_size[0]}px; height: #{block_size[1]}px;">#{link}</div>)

    if post.use_jpeg?(@current_user) && !options[:disable_jpeg_direct_links]
      if post.tags.include?("dakimakura") && !@current_user.is_contributor_or_higher?
        dl_width = post.jpeg_width.to_i
        dl_height = post.jpeg_height.to_i
        dl_url = post.sample_url
      else
        dl_width = post.jpeg_width.to_i
        dl_height = post.jpeg_height.to_i
        dl_url = post.jpeg_url
      end
    else
      if post.tags.include?("dakimakura") && !@current_user.is_contributor_or_higher?
        dl_width = post.width.to_i
        dl_height = post.height.to_i
        dl_url = post.sample_url
      else
        dl_width = post.width.to_i
        dl_height = post.height.to_i
        dl_url = post.file_url
      end
    end

    directlink_info =
      %(<span class="directlink-info">) +
        %(<img class="directlink-icon directlink-icon-large" src="#{image_path "ddl_large.gif"}" alt="">) +
        %(<img class="directlink-icon directlink-icon-small" src="#{image_path "ddl.gif"}" alt="">) +
        %(<img class="parent-display" src="#{image_path "post-star-parent.gif"}" alt="">) +
        %(<img class="child-display" src="#{image_path "post-star-child.gif"}" alt="">) +
        %(<img class="flagged-display" src="#{image_path "post-star-flagged.gif"}" alt="">) +
        %(<img class="pending-display" src="#{image_path "post-star-pending.gif"}" alt="">) +
        %(</span>)
    li_class = ""

    ddl_class = "directlink"
    ddl_class += (post.width.to_i > 1500 || post.height.to_i > 1500) ? " largeimg" : " smallimg"

    if options[:similarity]
      icon = %(<img src="#{post.service_icon}" alt="#{post.service}" class="service-icon" id="source">)

      ddl_class += " similar similar-directlink"
      li_class += " similar-match" if options[:similarity].to_f >= 90 rescue false
      li_class += " similar-original" if options[:similarity].to_s == "Original"
      directlink_info = %(<span class="similar-text">#{icon}</span>#{directlink_info})
    end

    if options[:hide_directlink]
      directlink = ""
    else
      directlink_res = %(<span class="directlink-res">#{dl_width} x #{dl_height}</span>)
      directlink = %(<a class="#{ddl_class}" href="#{dl_url}">#{directlink_info}#{directlink_res}</a>)
    end

    if is_post
      # Hide regular posts by default.  They'll be unhidden by the scripts once the
      # blacklists are loaded.  Don't do this for ExternalPost, which don't support
      # blacklists.
      li_class += " javascript-hide" if options[:blacklisting]
      li_class += " creator-id-#{post.user_id}"
    end
    li_class += " flagged" if post.is_flagged?
    li_class += " has-children" if post.has_children?
    li_class += " has-parent" if post.parent_id
    li_class += " pending" if post.is_pending?
    li_class += " mode-browse" if options[:display] == :large
    # We need to specify a width on the <li>, since IE7 won't figure it out on its own.
    item = %(<li style="width: #{block_size[0] + 10}px;" id="p#{post.id}" class="#{li_class}">#{div}#{directlink}</li>)
    item.html_safe
  end

  def print_ext_similarity_preview(post, options = {})
    image_class = "preview external"
    width, height = post.preview_dimensions

    # Set no-browser-link on external image links, so the Post.InitBrowserLinks knows not to
    # change these links to post/browse.
    image = %(<img src="#{post.preview_url}" alt="#{(post.md5)}" class="#{image_class} width="#{width}" height="#{height}">)
    link = %(<a class="thumb" href="#{post.url} class='no-browser-link'">#{image}</a>)
    icon = %(<img src="#{post.service_icon}" alt="#{post.service}" class="service-icon" id="source">)
    div = %(<div class="inner">#{link}</div>)

    size = if post.width > 0 then (%{ (#{post.width}x#{post.height})}) else "" end
    similarity_class = "similar"
    similarity_class += " similar-match" if options[:similarity].to_f >= 90 rescue false
    similarity_class += " similar-original" if options[:similarity].to_s == "Original"
    similarity_text = options[:similarity].to_s == "Original" ? "Image" : "#{options[:similarity].to_i}%"
    similarity = %(<a class="#{similarity_class}" href="#{post.url}"><span>#{icon}#{similarity_text}#{size}</span></a>)
    li_class = ""
    item = %(<li id="p#{post.id}" class="#{li_class}">#{div}#{similarity}</li>)
    item
  end

  def vote_tooltip_widget
    '<span class="vote-desc"></span>'.html_safe
  end

  def vote_widget(user, className = "standard-vote-widget")
    html = ""

    html << %(<span class="stars #{className}">)

    unless user.is_anonymous?
      (0..3).each do |vote|
        html << %(<a href="#" class="star star-#{vote} star-off"></a>)
      end

      html << %(<span class="vote-up-block"><a class="star vote-up" href="#"></a></span>)
    end

    html << %(</span>)
    html.html_safe
  end

  def get_service_icon(service)
    ExternalPost.get_service_icon(service)
  end

  def similar_link_params(new_params)
    params.permit(:search_id, :services, :threshold, :forcegray).merge(new_params)
  end

  def size_mpix(post)
    mpix = (post.width * post.height).to_f / 1_000_000

    format("%.2f MP", mpix)
  end
end
