# encoding: utf-8
require 'digest/md5'

class ApplicationController < ActionController::Base
  before_filter :set_locale
  before_filter :sanitize_params
 
  def set_locale
    if params[:locale] and CONFIG['available_locales'].include?(params[:locale])
      cookies['locale'] = { :value => params[:locale], :expires => 1.year.from_now }
      I18n.locale = params[:locale].to_sym
    elsif cookies['locale'] and CONFIG['available_locales'].include?(cookies['locale'])
      I18n.locale = cookies['locale'].to_sym
    end
  end

  def sanitize_params
    if params.is_a? Hash
      if params[:page]
        p = params[:page].to_i
        p = 1 if p < 1
        params[:page] = p
      else
        params[:page] = 1
      end
    else
      params = {}
    end
  end

  # This is a proxy class to make various nil checks unnecessary
  class AnonymousUser
    def id
      0
    end

    def level
      0
    end

    def name
      "Anonymous"
    end

    def pretty_name
      "Anonymous"
    end

    def is_anonymous?
      true
    end

    def has_permission?(obj, foreign_key = :user_id)
      false
    end

    def can_change?(record, attribute)
      method = "can_change_#{attribute.to_s}?"
      if record.respond_to?(method)
        record.__send__(method, self)
      elsif record.respond_to?(:can_change?)
        record.can_change?(self, attribute)
      else
        false
      end
    end

    def show_samples?
      true
    end

    def has_avatar?
      false
    end

    def language; ""; end
    def secondary_languages; ""; end
    def secondary_language_array; []; end
    def pool_browse_mode; 1; end
    def always_resize_images; true; end

    CONFIG["user_levels"].each do |name, value|
      normalized_name = name.downcase.gsub(/ /, "_")

      define_method("is_#{normalized_name}?") do
        false
      end

      define_method("is_#{normalized_name}_or_higher?") do
        false
      end

      define_method("is_#{normalized_name}_or_lower?") do
        true
      end
    end
  end

  module LoginSystem
    protected
    def access_denied
      previous_url = params[:url] || request.fullpath

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Access denied"; redirect_to(:controller => "user", :action => "login", :url => previous_url)}
        fmt.xml {render :xml => {:success => false, :reason => "access denied"}.to_xml(:root => "response"), :status => 403}
        fmt.json {render :json => {:success => false, :reason => "access denied"}.to_json, :status => 403}
      end
    end

    def set_current_user
      if Rails.env == "test" && session[:user_id]
        @current_user = User.find_by_id(session[:user_id])
      end

      if @current_user == nil && session[:user_id]
        @current_user = User.find_by_id(session[:user_id])
      end

      if @current_user == nil && cookies[:login] && cookies[:pass_hash]
        @current_user = User.authenticate_hash(cookies[:login], cookies[:pass_hash])
      end

      if @current_user == nil && params[:login] && params[:password_hash]
        @current_user = User.authenticate_hash(params[:login], params[:password_hash])
      end

      if @current_user == nil && params[:user].is_a?(Hash)
        @current_user = User.authenticate(params[:user][:name], params[:user][:password])
      end

      if @current_user
        if @current_user.is_blocked? && @current_user.ban && @current_user.ban.expires_at < Time.now
          @current_user.update_attribute(:level, CONFIG["starting_level"])
          Ban.destroy_all("user_id = #{@current_user.id}")
        end

        session[:user_id] = @current_user.id
      else
        @current_user = AnonymousUser.new
      end

      # For convenient access in activerecord models
      Thread.current["danbooru-user"] = @current_user
      Thread.current["danbooru-user_id"] = @current_user.id
      Thread.current["danbooru-ip_addr"] = request.ip

      # Hash the user's IP to seed things like mirror selection.
      Thread.current["danbooru-ip_addr_seed"] = Digest::MD5.hexdigest(request.ip)[0..7].hex

      ActiveRecord::Base.init_history

      UserLog.access(@current_user, request)
    end

    def set_current_request
      # This is used by the menu in the default layout, to bold the current page.
      @current_request = request
    end

    def set_country
      @current_user_country = GeoIP.new(File.expand_path('db/GeoIP.dat', Rails.root)).country(request.ip).country_code2
    end

    CONFIG["user_levels"].each do |name, value|
      normalized_name = name.downcase.gsub(/ /, "_")

      define_method("#{normalized_name}_only") do
        if @current_user.__send__("is_#{normalized_name}_or_higher?")
          return true
        else
          access_denied()
        end
      end

      # For many actions, GET invokes the HTML UI, and a POST actually invokes
      # the action, so we often want to require higher access for POST (so the UI
      # can invoke the login dialog).
      define_method("post_#{normalized_name}_only") do
        return true unless request.post?

        if @current_user.__send__("is_#{normalized_name}_or_higher?")
          return true
        else
          access_denied()
        end
      end
    end
  end

  module RespondToHelpers
  protected
    def respond_to_success(notice, redirect_to_params, options = {})
      extra_api_params = options[:api] || {}

      respond_to do |fmt|
        fmt.html {flash[:notice] = notice ; redirect_to(redirect_to_params)}
        fmt.json {render :json => extra_api_params.merge(:success => true).to_json}
        fmt.xml {render :xml => extra_api_params.merge(:success => true).to_xml(:root => "response")}
      end
    end

    def respond_to_error(obj, redirect_to_params, options = {})
      extra_api_params = options[:api] || {}
      status = options[:status] || 500

      if obj.is_a?(ActiveRecord::Base)
        obj = obj.errors.full_messages.join(", ")
        status = 420
      end

      case status
      when 420
        status = "420 Invalid Record"

      when 421
        status = "421 User Throttled"

      when 422
        status = "422 Locked"

      when 423
        status = "423 Already Exists"

      when 424
        status = "424 Invalid Parameters"
      end

      respond_to do |fmt|
        fmt.html {flash[:notice] = "Error: #{obj}" ; redirect_to(redirect_to_params)}
        fmt.json {render :json => extra_api_params.merge(:success => false, :reason => obj).to_json, :status => status}
        fmt.xml {render :xml => extra_api_params.merge(:success => false, :reason => obj).to_xml(:root => "response"), :status => status}
      end
    end

    def respond_to_list(inst_var_name)
      inst_var = instance_variable_get("@#{inst_var_name}")

      respond_to do |fmt|
        fmt.html
        fmt.json {render :json => inst_var.to_json}
        fmt.xml {render :xml => inst_var.to_xml(:root => inst_var_name)}
      end
    end

    def render_error(record)
      @record = record
      render :status => 500, :layout => "bare", :inline => "<%= error_messages_for('record') %>"
    end

  end

  include LoginSystem
  include RespondToHelpers
  include CacheHelper
  #local_addresses.clear

  before_filter :set_title
  before_filter :set_current_user
  before_filter :set_current_request
  before_filter :set_country
  before_filter :check_ip_ban
  after_filter :init_cookies
  protect_from_forgery

  protected :build_cache_key
  protected :get_cache_key

  def get_ip_ban()
    ban = IpBans.find(:first, :conditions => ["? <<= ip_addr", request.ip])
    if not ban then return nil end
    return ban
  end

  protected
  def check_ip_ban
    if request.parameters[:controller] == "banned" and request.parameters[:action] == "index" then
      return
    end

    ban = get_ip_ban()
    if not ban then
      return
    end

    if ban.expires_at && ban.expires_at < Time.now then
      IpBans.destroy_all("ip_addr = '#{request.ip}'")
      return
    end

    redirect_to :controller => "banned", :action => "index"
  end

  def set_title(title = CONFIG["app_name"])
    @page_title = CGI.escapeHTML(title)
  end

  def save_tags_to_cookie
    if params[:tags] || (params[:post] && params[:post][:tags])
      tags = TagAlias.to_aliased((params[:tags] || params[:post][:tags]).downcase.scan(/\S+/))
      tags += cookies["recent_tags"].to_s.to_valid_utf8.scan(/\S+/)
      cookies["recent_tags"] = tags.slice(0, 20).join(" ")
    end
  end

  def set_cache_headers
    response.headers["Cache-Control"] = "max-age=300"
  end

  def cache_action
    if request.method == :get && request.env !~ /Googlebot/ && params[:format] != "xml" && params[:format] != "json"
      key, expiry = get_cache_key(controller_name, action_name, params, :user => @current_user)

      if key && key.size < 200
        cached = Rails.cache.read(key)

        unless cached.blank?
          render :text => cached, :layout => false
          return
        end
      end

      yield

      if key && response.headers['Status'] =~ /^200/
        Rails.cache.write(key, response.body, :expires_in => expiry)
      end
    else
      yield
    end
  end

  def init_cookies
    return if params[:format] == "xml" || params[:format] == "json"

    forum_posts = ForumPost.find(:all, :order => "updated_at DESC", :limit => 10, :conditions => "parent_id IS NULL")
    cookies["current_forum_posts"] = forum_posts.map { |fp|
      if @current_user.is_anonymous?
        updated = false
      else
        updated = fp.updated_at > @current_user.last_forum_topic_read_at
      end
      [fp.title, fp.id, updated, (fp.response_count / 30.0).ceil]
    }.to_json

    cookies["country"] = @current_user_country

    unless @current_user.is_anonymous?
      cookies["user_id"] = @current_user.id.to_s

      cookies["user_info"] = @current_user.user_info_cookie

      if @current_user.has_mail?
        cookies["has_mail"] = "1"
      else
        cookies["has_mail"] = "0"
      end

      if @current_user.is_privileged_or_higher? && ForumPost.updated?(@current_user)
        cookies["forum_updated"] = "1"
      else
        cookies["forum_updated"] = "0"
      end

      if @current_user.is_privileged_or_higher? && Comment.updated?(@current_user)
        cookies["comments_updated"] = "1"
      else
        cookies["comments_updated"] = "0"
      end

      if @current_user.is_janitor_or_higher? then
        mod_pending = Post.count(:conditions => "status = 'flagged' or status = 'pending'")
        cookies["mod_pending"] = mod_pending.to_s
      end

      if @current_user.is_blocked?
        if @current_user.ban
          cookies["block_reason"] = "You have been blocked. Reason: #{@current_user.ban.reason}. Expires: #{@current_user.ban.expires_at.strftime('%Y-%m-%d')}"
        else
          cookies["block_reason"] = "You have been blocked."
        end
      else
        cookies["block_reason"] = ""
      end

      if @current_user.always_resize_images?
        cookies["resize_image"] = "1"
      else
        cookies["resize_image"] = "0"
      end

      if @current_user.show_advanced_editing
        cookies["show_advanced_editing"] = "1"
      else
        cookies["show_advanced_editing"] = "0"
      end
      cookies["my_tags"] = @current_user.my_tags
      cookies["blacklisted_tags"] = @current_user.blacklisted_tags_array
      cookies["held_post_count"] = @current_user.held_post_count.to_s
    else
      cookies.delete :user_info
      cookies["blacklisted_tags"] = CONFIG["default_blacklists"]
    end

    if flash[:notice] then
      cookies["notice"] = flash[:notice]
    end
  end

  private

    def admin_only
      access_denied unless @current_user.is_admin?
    end
    def member_only
      access_denied unless @current_user.is_member_or_higher?
    end
    def post_privileged_only
      access_denied unless @current_user.is_privileged_or_higher?
    end
    def post_member_only
      access_denied unless @current_user.is_member_or_higher?
    end
    def no_anonymous
      access_denied if @current_user.is_anonymous?
    end
end
