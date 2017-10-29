module ApplicationHelper
  def atom_title
    base_title = CONFIG["app_name"]
    if content_for? :title
      "#{h base_title} - #{content_for(:title)}".html_safe
    else
      base_title
    end
  end

  def html_title
    base_title = CONFIG["app_name"]
    if content_for? :title
      content_for(:title) + " | #{base_title}"
    else
      base_title
    end
  end

  def navbar_link_to(text, options, html_options = nil)
    if options[:controller] == params[:controller]
      klass = "current-page"
    else
      klass = nil
    end

    if %w(tag_alias tag_implication).include?(params[:controller]) && options[:controller] == "tag"
      klass = "current-page"
    end

    content_tag("li", link_to(text, options, html_options), :class => klass)
  end

  def timeago(time, options = {})
    options[:class] ||= ""
    options[:class] << " js-timeago"

    content_tag(:time, time.to_s, options.merge(datetime: time.getutc.iso8601)) if time
  end

  def format_text(text, _options = {})
    # The parses is more or less html safe
    # FIXME: for some reason rbx requires force encoding here.
    DText.parse(text).force_encoding("utf-8").html_safe
  end

  def format_inline(inline, num, id, preview_html = nil)
    if inline.inline_images.empty?
      return ""
    end

    url = inline.inline_images.first.preview_url
    unless preview_html
      preview_html = %(<img src="#{url}">)
    end
    id_text = "inline-%s-%i" % [id, num]
    block = %(
      <div class="inline-image" id="#{id_text}">
        <div class="inline-thumb" style="display: inline;">
        #{preview_html}
        </div>
        <div class="expanded-image" style="display: none;">
          <div class="expanded-image-ui"></div>
          <span class="main-inline-image"></span>
        </div>
      </div>
    )
    inline_id = "inline-%s-%i" % [id, num]
    # FIXME: for some reason rails invoked the old, useless json_escape when
    #        used here.
    script = 'InlineImage.register("%s", %s);' % [inline_id, inline.to_json.gsub("/", '\/')]
    [block.html_safe, script.html_safe, inline_id]
  end

  def format_inlines(text, id)
    num = 0
    list = []
    text.gsub!(/image #\d+/i) do |t|
      i = Inline.find_by(:id => t[7..-1])
      if i
        block, script = format_inline(i, num, id)
        list << script
        num += 1
        block
      else
        t
      end
    end

    if num > 0
      text << '<script language="javascript">' + list.join("\n") + "</script>"
    end

    text.html_safe
  end

  def id_to_color(id)
    r = id % 255
    g = (id >> 8) % 255
    b = (id >> 16) % 255
    "rgb(#{r}, #{g}, #{b})"
  end

  def tag_header(tags)
    unless tags.blank?
      ("/" + Tag.scan_query(tags).map { |t| link_to(t.tr("_", " "), :controller => "post", :action => "index", :tags => t) }.join("+")).html_safe
    end
  end

  def compact_time(time)
    if time > Time.now.beginning_of_day
      time.strftime("%H:%M")
    elsif time > Time.now.beginning_of_year
      time.strftime("%b %e")
    else
      time.strftime("%b %e, %Y")
    end
  end

  def content_for_prefix(name)
    content_current = content_for(name)

    content_for(name, :flush => true) { yield }
    content_for(name, content_current)
  end

  def navigation_links(post)
    html = []

    if post.is_a?(Post)
      html << tag("link", :rel => "prev", :title => "Previous Post", :href => url_for(:controller => "post", :action => "show", :id => post.id - 1))
      html << tag("link", :rel => "next", :title => "Next Post", :href => url_for(:controller => "post", :action => "show", :id => post.id + 1))

    elsif post.is_a?(Array)
      posts = post
      new_params = params.to_unsafe_h.merge :only_path => true

      if posts.previous_page.present?
        html << tag("link", :href => url_for(new_params.merge :page => 1), :rel => "first", :title => "First Page")
        html << tag("link", :href => url_for(new_params.merge :page => posts.previous_page), :rel => "prev", :title => "Previous Page")
      end

      if posts.next_page.present?
        html << tag("link", :href => url_for(new_params.merge :page => posts.next_page), :rel => "next", :title => "Next Page")
        html << tag("link", :href => url_for(new_params.merge :page => posts.total_pages), :rel => "last", :title => "Last Page")
      end
    end

    html.join("\n").html_safe
  end

  def make_menu_item(label, url_options = {}, options = {})
    item = {
      :label => label,
      :dest => url_for(url_options),
      :class_names => options[:class_names] || []
    }
    item[:html_id] = options[:html_id] if options[:html_id]
    item[:name] = options[:name] if options[:name]

    if options[:level] && need_signup?(options[:level])
      item[:login] = true
    end

    if url_options[:controller].to_s == controller.controller_name.to_s
      item[:class_names] << "current-menu"
    end

    item
  end

  def make_main_item(*options)
    item = make_menu_item(*options)
    @top_menu_items ||= []
    @top_menu_items << item
    json_escape item.to_json.html_safe
  end

  def make_sub_item(*options)
    item = make_menu_item(*options)
    json_escape item.to_json.html_safe
  end

  def get_help_action_for_controller(controller)
    singular = %w(forum wiki)
    help_action = controller.to_s
    if singular.include?(help_action)
      return help_action
    else
      return help_action.pluralize
    end
  end

  # Return true if the user can access the given level, or if creating an
  # account would.  This is only actually used for actions that require
  # privileged or higher; it's assumed that starting_level is no lower
  # than member.
  def can_access?(level)
    needed_level = User.get_user_level(level)
    starting_level = CONFIG["starting_level"]
    user_level = @current_user.level
    return true if user_level.to_i >= needed_level
    return true if starting_level >= needed_level
    false
  end

  # Return true if the starting level is high enough to execute
  # this action.  This is used by User.js.
  def need_signup?(level)
    CONFIG["starting_level"] >= User.get_user_level(level)
  end
  module_function :need_signup?

  # Submit tag with a twist: removes name from tag form data so it doesn't add
  # unnecessary query string on forms with GET method.
  def get_submit_tag(value = "Save changes", options = {})
    submit_tag value, options.merge(:name => nil)
  end

  # Text field tag without id.
  def generic_text_field_tag(name, value = nil, options = {})
    text_field_tag name, value, options.merge(:id => nil)
  end

  # Cache with locale. Only works when the name is an array or string.
  def local_cache(name = {}, options = {}, &block)
    if (name.is_a? String) || (name.is_a? Array)
      name = Array(name)
      name << I18n.locale
    end
    cache name, options, &block
  end

  def with_host(url)
    return url if url[0] != "/"

    "#{request.protocol}#{request.host_with_port}#{url}"
  end
end
