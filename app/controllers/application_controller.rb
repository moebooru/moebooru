# encoding: utf-8
require "digest/md5"

class ApplicationController < ActionController::Base
  protect_from_forgery
  rescue_from ActiveRecord::StatementInvalid, :with => :rescue_pg_invalid_query
  before_action :filter_spam
  before_action :set_locale

  module LoginSystem
    protected

    def access_denied
      previous_url = params[:url]

      if previous_url.blank?
        if request.method == "GET"
          previous_url = request.fullpath
        else
          referrer = request.referer
          if referrer.try(:index, CONFIG["url_base"]) == 0
            previous_url = referrer[CONFIG["url_base"].length..-1].sub /\A\/*/, "/"
          end
        end
      end

      respond_to do |fmt|
        fmt.html { redirect_to user_login_path(:url => previous_url), :notice => "Access denied" }
        fmt.xml { render :xml => { :success => false, :reason => "access denied" }.to_xml(:root => "response"), :status => 403 }
        fmt.json { render :json => { :success => false, :reason => "access denied" }.to_json, :status => 403 }
        fmt.js { head :forbidden }
      end
    end

    def set_current_user
      if Rails.env.test? && session[:user_id]
        @current_user = User.find_by(:id => session[:user_id])
      end

      if !@current_user && params[:api_key] && params[:username]
        @from_api = true
        @current_user = User.authenticate_with_api_key(params[:username], params[:api_key])
        return head(:forbidden) unless @current_user
      end

      if @current_user.nil? && session[:user_id]
        @current_user = User.find_by_id(session[:user_id])
      end

      if @current_user.nil? && cookies[:login] && cookies[:pass_hash]
        @current_user = User.authenticate_hash(cookies[:login], cookies[:pass_hash])
      end

      if @current_user.nil? && params[:login] && params[:password_hash]
        @current_user = User.authenticate_hash(params[:login], params[:password_hash])
      end

      if @current_user.nil? && params[:user].is_a?(ActionController::Parameters)
        @current_user = User.authenticate(params[:user][:name], params[:user][:password])
      end

      if @current_user
        if @current_user.is_blocked? && @current_user.ban && @current_user.ban.expires_at < Time.now
          @current_user.update_attribute(:level, CONFIG["starting_level"])
          Ban.where(:user_id => @current_user.id).destroy_all
        end

        session[:user_id] = @current_user.id
      else
        @current_user = AnonymousUser.new
      end

      # For convenient access in activerecord models
      Thread.current["danbooru-user"] = @current_user
      Thread.current["danbooru-user_id"] = @current_user.id
      Thread.current["danbooru-ip_addr"] = request.remote_ip

      # Hash the user's IP to seed things like mirror selection.
      Thread.current["danbooru-ip_addr_seed"] = Digest::MD5.hexdigest(request.remote_ip)[0..7].hex

      ActiveRecord::Base.init_history

      @current_user.log(request.remote_ip) unless @current_user.is_anonymous?
    end

    def set_country
      @current_user_country = Rails.cache.fetch({ :type => :geoip, :ip => request.remote_ip }, :expires_in => 1.month) do
        begin
          GeoIP.new(Rails.root.join("db", "GeoIP.dat").to_s).country(request.remote_ip).country_code2
        rescue
          "--"
        end
      end
    end

    CONFIG["user_levels"].each do |name, _value|
      normalized_name = name.downcase.gsub(/ /, "_")

      define_method("#{normalized_name}_only") do
        if @current_user.__send__("is_#{normalized_name}_or_higher?")
          return true
        else
          access_denied
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
          access_denied
        end
      end
    end
  end

  module RespondToHelpers
    protected

    def respond_to_success(notice, redirect_to_params, options = {})
      extra_api_params = options[:api] || {}

      respond_to do |fmt|
        fmt.html { redirect_to redirect_to_params, :notice => notice }
        fmt.json { render :json => extra_api_params.merge(:success => true).to_json }
        fmt.xml { render :xml => extra_api_params.merge(:success => true).to_xml(:root => "response") }
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
        fmt.html { redirect_to redirect_to_params, :notice => "Error: #{obj}" }
        fmt.json { render :json => extra_api_params.merge(:success => false, :reason => obj).to_json, :status => status }
        fmt.xml { render :xml => extra_api_params.merge(:success => false, :reason => obj).to_xml(:root => "response"), :status => status }
      end
    end

    def respond_to_list(inst_var_name, formats = {})
      inst_var = instance_variable_get("@#{inst_var_name}")

      respond_to do |fmt|
        fmt.html
        fmt.atom if formats[:atom]
        fmt.json { render :json => inst_var.to_json }
        fmt.xml { render :xml => inst_var.to_xml(:root => inst_var_name) }
      end
    end

    def render_error(record)
      @record = record
      render :status => 500, :layout => "bare", :inline => "<%= render 'shared/error_messages', :object => @record %>"
    end
  end

  include LoginSystem
  include RespondToHelpers
  include CacheHelper
  include SessionsHelper
  # local_addresses.clear

  before_action :set_current_user
  before_action :mini_profiler_check if Rails.env.development?
  before_action :limit_api
  before_action :set_country
  before_action :check_ip_ban
  after_action :init_cookies

  protected :build_cache_key
  protected :get_cache_key

  def get_ip_ban
    IpBans.find_by("? <<= ip_addr", request.remote_ip)
  end

  protected

  def check_ip_ban
    return if params[:controller] == "banned" && params[:action] == "index"

    ban = get_ip_ban
    return unless ban

    if ban.expires_at && ban.expires_at < Time.now
      IpBans.where(:ip_addr => request.remote_ip).destroy_all
      return
    end

    redirect_to :controller => "banned", :action => "index"
  end

  def save_tags_to_cookie
    if params[:tags] || (params[:post] && params[:post][:tags])
      tags = TagAlias.to_aliased((params[:tags] || params[:post][:tags]).to_s.to_valid_utf8.downcase.split)
      tags += cookies["recent_tags"].to_s.to_valid_utf8.downcase.split
      cookies["recent_tags"] = tags.uniq.slice(0, 20).join(" ")
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
          render :plain => cached
          return
        end
      end

      yield

      if key && response.headers["Status"] =~ /^200/
        Rails.cache.write(key, response.body, :expires_in => expiry)
      end
    else
      yield
    end
  end

  def init_cookies
    return if params[:format] == "xml" || params[:format] == "json"

    cookies["forum_post_last_read_at"] = if @current_user.is_anonymous?
                                           Time.now
                                         else
                                           @current_user.last_forum_topic_read_at || Time.at(0)
                                         end.to_json

    cookies["country"] = @current_user_country

    if @current_user.is_anonymous?
      cookies.delete :user_info
    else
      cookies["user_id"] = @current_user.id.to_s

      cookies["user_info"] = @current_user.user_info_cookie

      if @current_user.has_mail?
        cookies["has_mail"] = "1"
      else
        cookies["has_mail"] = "0"
      end

      if @current_user.is_privileged_or_higher? && Comment.updated?(@current_user)
        cookies["comments_updated"] = "1"
      else
        cookies["comments_updated"] = "0"
      end

      if @current_user.is_janitor_or_higher?
        mod_pending = Post.where("status" => %w(flagged pending)).count
        cookies["mod_pending"] = mod_pending
      end

      if @current_user.is_blocked?
        if @current_user.ban
          cookies["block_reason"] = "You have been blocked. Reason: #{@current_user.ban.reason}. Expires: #{@current_user.ban.expires_at.strftime("%Y-%m-%d")}"
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
      cookies["held_post_count"] = @current_user.held_post_count.to_s
    end

    if flash[:notice]
      cookies["notice"] = flash[:notice]
    end
  end

  private

  def limit_api
    if @from_api && !(request.format.xml? || request.format.json? || request.format.zip?)
      request.session_options[:skip] = true
      head :not_found
    end
  end

  # FIXME: better error handling instead of blank 400.
  def rescue_pg_invalid_query(exception)
    case exception.cause
    when PG::DatetimeFieldOverflow, PG::NumericValueOutOfRange
      head :bad_request
    else
      raise exception
    end
  end

  def set_query_date
    @query_date ||= if params[:year] && params[:month]
                      Time.local params[:year], params[:month], (params[:day] || 1)
                    else
                      Time.current
                    end
  rescue ArgumentError
    head :bad_request
  end

  def set_locale
    if params[:locale] && CONFIG["available_locales"].include?(params[:locale])
      cookies["locale"] = { :value => params[:locale], :expires => 1.year.from_now }
      I18n.locale = params[:locale].to_sym
    elsif cookies["locale"] && CONFIG["available_locales"].include?(cookies["locale"])
      I18n.locale = cookies["locale"].to_sym
    else
      I18n.locale = CONFIG["default_locale"]
    end
  end

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

  def sanitize_id
    params[:id] = params[:id].to_i
  end

  def mini_profiler_check
    if @current_user.is_admin_or_higher?
      Rack::MiniProfiler.authorize_request
    end
  end

  def filter_spam
    head :ok if params[:url1].present?
  end
end
