module PostHelper
  def source_link(source, abbreviate = true)
    if source.empty?
      "none"
    elsif source[/^http/]
      text = source
      text = text[7, 20] + "..." if abbreviate
      link_to text, source
    else
      source
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
    unless CONFIG["can_see_post"].call(@current_user, post)
      return ""
    end

    image_class = "preview"
    image_id = options[:image_id]
    image_id = %{id="#{h(image_id)}"} if image_id
    image_title = h("Rating: #{post.pretty_rating} Score: #{post.score} Tags: #{h(post.cached_tags)} User:#{post.author}")
    link_onclick = options[:onclick]
    link_onclick = %{onclick="#{link_onclick}"} if link_onclick
    link_onmouseover = %{ onmouseover="#{options[:onmouseover]}"} if options[:onmouseover]
    link_onmouseout = %{ onmouseout="#{options[:onmouseout]}"} if options[:onmouseout]

    if options[:display] == :block then
      # Show the thumbnail at its actual resolution, and crop it with northern orientation
      # to a smaller size.
      width, height = post.raw_preview_dimensions
      block_size = [200, 200]
      visible_width = [block_size[0], width].min
      crop_left = (width - visible_width) / 2
    elsif options[:display] == :large then
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

    image = %{<img src="#{post.preview_url}" style="margin-left: #{-crop_left}px;" alt="#{image_title}" class="#{image_class}" title="#{image_title}" #{image_id} width="#{width}" height="#{height}">}
    plid = %{<span class="plid">#pl http://#{h CONFIG["server_host"]}/post/show/#{post.id}</span>}
    link = %{<a class="thumb" href="/post/show/#{post.id}/#{u(post.tag_title)}" #{link_onclick}#{link_onmouseover}#{link_onmouseout}>#{image}#{plid}</a>}
    div = %{<div class="inner" style="width: #{block_size[0]}px; height: #{block_size[1]}px;">#{link}</div>}
    
    if post.use_jpeg?(@current_user) and not options[:disable_jpeg_direct_links] then
      dl_width = post.jpeg_width.to_i
      dl_height = post.jpeg_height.to_i
      dl_url = post.jpeg_url
    else
      dl_width = post.width.to_i
      dl_height = post.height.to_i
      dl_url = post.file_url
    end

    directlink_info = %{
      <span class="directlink-info">
        <span class="parent-display">X</span>
        <span class="child-display">X</span>
        <span class="flagged-display">!</span>
        <span class="pending-display">P</span>
      </span>
    }

    if options[:similarity]
      icon = %{<img src="/favicon.ico" class="service-icon" id="source">}
      size = %{ (#{dl_width}x#{dl_height})}

      similarity_class = "similar similar_directlink"
      similarity_class += " similar_original" if options[:similarity].to_s == "Original"
      similarity_class += " similar-match" if options[:similarity].to_f >= 90 rescue false
      similarity_text = options[:similarity].to_s == "Original"?
        (if @initial then "Your post" else "Original" end):
       %{#{options[:similarity].to_i}%}

      directlink = %{<a class="#{similarity_class}" href="#{dl_url}"><span class="similar-text">#{icon}#{similarity_text}#{size}</span>#{directlink_info}</a>}
    else
      ddl_class = "directlink"
      if post.width.to_i > 1500 or post.height.to_i > 1500 
        ddl_class += " largeimg"
      end
      directlink = %{<a class="#{ddl_class}" href="#{dl_url}">#{directlink_info}<span class="directlink-res">#{dl_width} x #{dl_height}</span></a>}
    end
    directlink = "" if options[:hide_directlink]
      
    li_class = ""
    li_class += " javascript-hide" if options[:blacklisting]
    li_class += " creator-id-#{post.user_id}"
    li_class += " flagged" if post.is_flagged?
    li_class += " has-children" if post.has_children?
    li_class += " has-parent" if post.parent_id
    li_class += " pending" if post.is_pending?
    # We need to specify a width on the <li>, since IE7 won't figure it out on its own.
    item = %{<li style="width: #{block_size[0]+10}px;" id="p#{post.id}" class="#{li_class}">#{div}#{directlink}</li>}
    return item
  end

  def print_ext_similarity_preview(post, options = {})
    image_class = "preview external"
    width, height = post.preview_dimensions

    image = %{<img src="#{post.preview_url}" alt="#{(post.md5)}" class="#{image_class} width="#{width}" height="#{height}">}
    link = %{<a href="#{post.url}">#{image}</a>}
    icon = %{<img src="#{post.service_icon}" alt="#{post.service}" class="service-icon" id="source">}
    span = %{<span class="thumb">#{link}</span>}

    size = if post.width > 0 then (%{ (#{post.width}x#{post.height})}) else "" end
    similarity_class = "similar"
    similarity_class += " similar-match" if options[:similarity].to_f >= 90 rescue false
    similarity_class += " similar_original" if options[:similarity].to_s == "Original"
    similarity_text = options[:similarity].to_s == "Original"?  "Image":%{#{options[:similarity].to_i}%}
    similarity = %{<a class="#{similarity_class}" href="#{post.url}"><span>#{icon}#{similarity_text}#{size}</span></a>}
    item = %{<li id="p#{post.id}">#{span}#{similarity}</li>}
    return item
  end

  def vote_tooltip_widget(post)
    return %{<span class="vote-desc" id="vote-desc-#{post.id}"></span>}
  end

  def vote_widget(post, user, options = {})
    html = []
    
    html << %{<span class="stars" id="stars-#{post.id}">}
    
    if user.is_anonymous?
      current_user_vote = -100
    else
      current_user_vote = PostVotes.find_by_ids(user.id, post.id).score rescue 0
    end
    
    #(CONFIG["vote_sum_min"]..CONFIG["vote_sum_max"]).each do |vote|
    if !user.is_anonymous?
      html << link_to_function('↶', "Post.vote(#{post.id}, 0)", :class => "star", :onmouseover => "Post.vote_mouse_over('Remove vote', #{post.id}, 0)", :onmouseout => "Post.vote_mouse_out('', #{post.id}, 0)")
      html << " "

      (1..3).each do |vote|
        star = '<span class="score-on">★</span><span class="score-off score-visible">☆</span>'
        
        desc = CONFIG["vote_descriptions"][vote]

        html << link_to_function(star, "Post.vote(#{post.id}, #{vote})", :class => "star star-#{vote}", :id => "star-#{vote}-#{post.id}", :onmouseover => "Post.vote_mouse_over('#{desc}', #{post.id}, #{vote})", :onmouseout => "Post.vote_mouse_out('#{desc}', #{post.id}, #{vote})")
      end

      html << " (" + link_to_function('vote up', "Post.vote(#{post.id}, Post.posts.get(#{post.id}).vote + 1)", :class => "star") + ")"
    else
      html << "(" + link_to_function('vote up', "Post.vote(#{post.id}, +1)", :class => "star") + ")"
    end
    
    html << %{</span>}
    return html
  end

  def get_tag_types(posts)
    post_tags = []
    posts.each { |post| post_tags += post.cached_tags.split(/ /) }
    tag_types = {}
    post_tags.uniq.each { |tag| tag_types[tag] = Tag.type_name(tag) }
    return tag_types
  end

  def get_service_icon(service)
    ExternalPost.get_service_icon(service)
  end
end
