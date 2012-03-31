module ApplicationHelper
  # Scale percentage table widths to 100% to make variable column tables
  # easier.
  def scheme
    request.ssl? ? 'https://' : 'http://'
  end

  class TableScale
    def add(*list)
      @val = nil
      @list ||= []
      list.each { |val|
        @list << val.to_f
      }
      @idx ||= 0
    end

    def get
      @idx += 1
      get_idx(@idx - 1)
    end

    def get_idx(n)
      if !@val then
        # Scale the list to sum to 100%.
        #
        # Both FF3 and Opera treat values under 1% as unspecified.  (Why?)  If any value
        # is less than 1%, clamp it to 1% and recompute the remainder.
        @val = @list
        indexes = []
        @val.each_index { |idx| indexes << idx }
        while !indexes.empty?
          sum = @val.length - indexes.length # 1% for each 1% value we excluded
          indexes.each { |idx| sum += @val[idx] }
          break if sum == 0

          indexes.each { |idx| @val[idx] = [@val[idx] / (sum/100), 1].max }
          new_indexes = []
          indexes.each { |idx| new_indexes << idx if @val[idx] > 1 }
          break if indexes.length == new_indexes.length
          indexes = new_indexes
        end
      end
      "%.2f%%" % @val[n]
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

  def format_text(text, options = {})
    DText.parse(text)
  end

  def format_inline(inline, num, id, preview_html=nil)
    if inline.inline_images.empty? then
      return ""
    end

    url = inline.inline_images.first.preview_url
    if not preview_html
      preview_html = %{<img src="#{url}">}
    end
    id_text = "inline-%s-%i" % [id, num]
    block = %{
      <div class="inline-image" id="#{id_text}">
        <div class="inline-thumb" style="display: inline;">
        #{preview_html}
        </div>
        <div class="expanded-image" style="display: none;">
          <div class="expanded-image-ui"></div>
          <span class="main-inline-image"></span>
        </div>
      </div>
    }
    inline_id = "inline-%s-%i" % [id, num]
    script = 'InlineImage.register("%s", %s);' % [inline_id, inline.to_json]
    return block, script, inline_id
  end

  def format_inlines(text, id)
    num = 0
    list = []
    text.gsub!(/image #(\d+)/i) { |t|
      i = Inline.find($1) rescue nil
      if i then
        block, script = format_inline(i, num, id)
        list << script
        num += 1
        block
      else
        t
      end
    }

    if num > 0 then
      text << '<script language="javascript">' + list.join("\n") + '</script>'
    end

    text
  end
  
  def id_to_color(id)
    r = id % 255
    g = (id >> 8) % 255
    b = (id >> 16) % 255
    "rgb(#{r}, #{g}, #{b})"
  end

  def tag_header(tags)
    unless tags.blank?
      '/' + Tag.scan_query(tags).map {|t| link_to(t.tr("_", " "), :controller => "post", :action => "index", :tags => t)}.join("+")
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
  
  def time_ago_in_words(time)
    from_time = time
    to_time = Time.now
    distance_in_minutes = (((to_time - from_time).abs)/60).round
    distance_in_seconds = ((to_time - from_time).abs).round

    case distance_in_minutes
    when 0..1
      '1 minute'

    when 2..44
      "#{distance_in_minutes} minutes"

    when 45..89
      '1 hour'

    when 90..1439
      "#{(distance_in_minutes.to_f / 60.0).round} hours"

    when 1440..2879
      '1 day'

    when 2880..43199
      "#{(distance_in_minutes / 1440).round} days"

    when 43200..86399
      '1 month'

    when 86400..525959
      "#{(distance_in_minutes / 43200).round} months"

    else
      "%.1f years" % (distance_in_minutes / 525960.0)
    end
  end
  
  def content_for_prefix(name, &block)
    existing_content_for = instance_variable_get("@content_for_#{name}").to_s
    new_content_for      = (block_given? ? capture(&block) : content) + existing_content_for
    instance_variable_set("@content_for_#{name}", new_content_for)
  end

  def navigation_links(post)
    html = []
    
    if post.is_a?(Post)
      html << tag("link", :rel => "prev", :title => "Previous Post", :href => url_for(:controller => "post", :action => "show", :id => post.id - 1))
      html << tag("link", :rel => "next", :title => "Next Post", :href => url_for(:controller => "post", :action => "show", :id => post.id + 1))
      
    elsif post.is_a?(Array)
      posts = post
      
      unless posts.previous_page.nil?
        html << tag("link", :href => url_for(params.merge(:page => 1)), :rel => "first", :title => "First Page")
        html << tag("link", :href => url_for(params.merge(:page => posts.previous_page)), :rel => "prev", :title => "Previous Page")
      end

      unless posts.next_page.nil?
        html << tag("link", :href => url_for(params.merge(:page => posts.next_page)), :rel => "next", :title => "Next Page")
        html << tag("link", :href => url_for(params.merge(:page => posts.total_pages)), :rel => "last", :title => "Last Page")
      end
    end

    return html.join("\n")
  end  
  
  def make_menu_item(label, url_options = {}, options = {})
    item = {
      :label => label,
      :dest => url_for(url_options),
      :class_names => options[:class_names] || []
    }
    item[:html_id] = options[:html_id] if options[:html_id]
    item[:name] = options[:name] if options[:name]

    if options[:level] && need_signup?(options[:level]) then
      item[:login] = true
    end

    if url_options[:controller].to_s == @current_request.parameters[:controller].to_s
      item[:class_names] << "current-menu"
    end

    return item
  end

  def make_main_item(*options)
    item = make_menu_item(*options)
    @top_menu_items ||= []
    @top_menu_items << item
    return item.to_json
  end

  def make_sub_item(*options)
    item = make_menu_item(*options)
    return item.to_json
  end

  def get_help_action_for_controller(controller)
    singular = ["forum", "wiki"]
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
    return false
  end

  # Return true if the starting level is high enough to execute
  # this action.  This is used by User.js.
  def need_signup?(level)
    needed_level = User.get_user_level(level)
    starting_level = CONFIG["starting_level"]
    return starting_level >= needed_level
  end

  require "action_view/helpers/form_tag_helper.rb"
  include ActionView::Helpers::FormTagHelper
  alias_method :orig_form_tag, :form_tag
  def form_tag(url_for_options = {}, options = {}, *parameters_for_url, &block)
    # Add the need-signup class if signing up would allow a logged-out user to
    # execute this action.  User.js uses this to determine whether it should ask
    # the user to create an account.
    if options[:level]
      if need_signup?(options[:level])
        classes = (options[:class] || "").split(" ")
        classes += ["need-signup"]
        options[:class] = classes.join(" ")
      end
      options.delete(:level)
    end

    orig_form_tag url_for_options, options, *parameters_for_url, &block
  end

  require "action_view/helpers/javascript_helper.rb"
  include ActionView::Helpers::JavaScriptHelper
  alias_method :orig_link_to_function, :link_to_function
  def link_to_function(name, *args, &block)
    html_options = args.extract_options!
    if html_options[:level]
      if need_signup?(html_options[:level]) && args[0]
        args[0] = "User.run_login(false, function() { #{args[0]} })"
      end
      html_options.delete(:level)
    end
    args << html_options
    orig_link_to_function name, *args, &block
  end

  alias_method :orig_button_to_function, :button_to_function
  def button_to_function(name, *args, &block)
    html_options = args.extract_options!
    if html_options[:level]
      if need_signup?(html_options[:level]) && args[0]
        args[0] = "User.run_login(false, function() { #{args[0]} })"
      end
      html_options.delete(:level)
    end
    args << html_options
    orig_button_to_function name, *args, &block
  end

  require "action_view/helpers/url_helper.rb"
  include ActionView::Helpers::UrlHelper

private
  alias_method :orig_convert_options_to_javascript!, :convert_options_to_javascript!
  # This handles link_to (and others, not tested).
  def convert_options_to_javascript!(html_options, url = '')
    level = html_options["level"]
    html_options.delete("level")
    orig_convert_options_to_javascript!(html_options, url)
    if level
      if need_signup?(level)
        html_options["onclick"] = "if(!User.run_login_onclick(event)) return false; #{html_options["onclick"] || "return true;"}"
      end
    end
  end
end
