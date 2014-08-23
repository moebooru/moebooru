require "digest/sha2"

class UserController < ApplicationController
  layout "default"
  before_action :blocked_only, :only => [:authenticate, :update, :edit, :modify_blacklist]
  before_action :janitor_only, :only => [:invites]
  before_action :mod_only, :only => [:block, :unblock, :show_blocked_users]
  before_action :post_member_only, :only => [:set_avatar]
  before_action :no_anonymous, :only => [:change_password, :change_email, :show]
  helper :post, :tag_subscription
  helper :avatar

  protected
  def save_cookies(user)
    cookies[:login] = { :value => user.name, :expires => 1.year.from_now }
    cookies[:pass_hash] = { :value => user.password_hash, :expires => 1.year.from_now, :httponly => true }
    session[:user_id] = user.id
  end

  public
  def autocomplete_name
    keyword = params[:term].to_s
    @users = User.where(["name ILIKE ?", "*#{keyword}*".to_escaped_for_sql_like]).pluck(:name) if keyword.length >= 2
    respond_to do |format|
      format.json { render :json => (@users || []) }
    end
  end

  # FIXME: this method is crap and only function as temporary workaround
  #        until I convert the controllers to resourceful version which is
  #        planned for 3.2 branch (at least 3.2.1).
  def remove_avatar
    # When removing other user's avatar, ensure current user is mod or higher.
    if @current_user.id != params[:id] and !@current_user.is_mod_or_higher?
      access_denied
      return
    end
    @user = User.find(params[:id])
    @user.avatar_post_id = nil
    if @user.save
      flash[:notice] = "Avatar removed"
    else
      flash[:notice] = "Failed removing avatar"
    end
    redirect_to :action => :show, :id => params[:id]
  end

  def change_password
    @title = "Change Password"
    render :layout => "settings"
  end

  def change_email
    @title = "Change Email"
    @current_user.current_email = @current_user.email
    render :layout => "settings"
  end

  def show
    if params[:name]
      @user = User.find_by_name(params[:name])
    else
      @user = User.find(params[:id])
    end

    if @user.nil?
      redirect_to "/404"
    end
    if @current_user.is_mod_or_higher?
      @user_ips = @user.user_logs.order("created_at DESC").pluck("ip_addr").uniq
    end
    respond_to do |format|
      format.html
    end
  end

  def invites
    if request.post?
      if params[:member]
        begin
          @current_user.invite!(params[:member][:name], params[:member][:level])
          flash[:notice] = "User was invited"

        rescue ActiveRecord::RecordNotFound
          flash[:notice] = "Account not found"

        rescue User::NoInvites
          flash[:notice] = "You have no invites for use"

        rescue User::HasNegativeRecord
          flash[:notice] = "This use has a negative record and must be invited by an admin"
        end
      end

      redirect_to :action => "invites"
    else
      @invited_users = User.find(:all, :conditions => ["invited_by = ?", @current_user.id], :order => "lower(name)")
    end
  end

  def home
  end

  def index
    @users = User.paginate(User.generate_sql(params).merge(:per_page => 20, :page => page_number))
    respond_to_list("users")
  end

  def authenticate
    save_cookies(@current_user)

    if params[:url].blank?
      path = { :action => "home" }
    else
      path = params[:url]
    end

    respond_to_success("You are now logged in", path)
  end

  def check
    if request.post?
      user = User.find_by_name(params[:username])
      ret = { :exists => false }
      ret[:name] = params[:username]

      if !user
        respond_to_success("User does not exist", {}, :api => { :response => "unknown-user" }.merge(ret))
        return
      end

      # Return some basic information about the user even if the password isn't given, for
      # UI cosmetics.
      ret[:exists] = true
      ret[:id] = user.id
      ret[:name] = user.name
      ret[:no_email] = user.email.blank?

      user = User.authenticate(params[:username], params[:password] || "")
      if !user
        respond_to_success("Wrong password", {}, :api => { :response => "wrong-password" }.merge(ret))
        return
      end

      ret[:pass_hash] = user.password_hash
      ret[:user_info] = user.user_info_cookie
      respond_to_success("Successful", {}, :api => { :response => "success" }.merge(ret))
    else
      redirect_to root_path
    end
  end

  def login
    respond_to { |format| format.html }
  end

  def create
    user = User.create(params[:user])

    if user.errors.empty?
      save_cookies(user)

      ret = { :exists => false }
      ret[:name] = user.name
      ret[:id] = user.id
      ret[:pass_hash] = user.password_hash
      ret[:user_info] = user.user_info_cookie

      respond_to_success("New account created", { :action => "home" }, :api => { :response => "success" }.merge(ret))
    else
      error = user.errors.full_messages.join(", ")
      respond_to_success("Error: " + error, { :action => "signup" }, :api => { :response => "error", :errors => user.errors.full_messages })
    end
  end

  def signup
    @user = User.new
  end

  def logout
    session[:user_id] = nil
    cookies[:login] = nil
    cookies[:pass_hash] = nil

    dest = { :action => "home" }
    dest = params[:from] if params[:from]
    respond_to_success("You are now logged out", dest)
  end

  def update
    if params[:commit] == "Cancel"
      redirect_to :action => "home"
      return
    end

    if @current_user.update_attributes(params[:user])
      respond_to_success("Account settings saved", :action => "edit")
    else
      if params[:render] and params[:render][:view]
        render get_view_name_for_edit(params[:render][:view])
      else
        respond_to_error(@current_user, :action => "edit")
      end
    end
  end

  def modify_blacklist
    added_tags = params[:add] || []
    removed_tags = params[:remove] || []

    tags = @current_user.blacklisted_tags_array
    added_tags.each { |tag|
      tags << tag if !tags.include?(tag)
    }

    tags -= removed_tags

    if @current_user.update_attribute(:blacklisted_tags, tags.join("\n"))
      respond_to_success("Tag blacklist updated", { :action => "home" }, :api => { :result => @current_user.blacklisted_tags_array })
    else
      respond_to_error(@current_user, :action => "edit")
    end
  end

  def remove_from_blacklist
  end

  def edit
    @user = @current_user
    render :layout => "settings"
  end

  def reset_password
    if request.post?
      @user = User.find_by_name(params[:user][:name])

      if @user.nil?
        respond_to_error("That account does not exist", { :action => "reset_password" }, :api => { :result => "unknown-user" })
        return
      end

      if @user.email.blank?
        respond_to_error("You never supplied an email address, therefore you cannot have your password automatically reset",
                         { :action => "login" }, :api => { :result => "no-email" })
        return
      end

      if @user.email != params[:user][:email]
        respond_to_error("That is not the email address you supplied",
                         { :action => "login" }, :api => { :result => "wrong-email" })
        return
      end

      begin
        User.transaction do
          # If the email is invalid, abort the password reset
          new_password = @user.reset_password
          UserMailer.new_password(@user, new_password).deliver
          respond_to_success("Password reset. Check your email in a few minutes.",
                           { :action => "login" }, :api => { :result => "success" })
          return
        end
      rescue Net::SMTPSyntaxError, Net::SMTPFatalError
        respond_to_success("Your email address was invalid",
                         { :action => "login" }, :api => { :result => "invalid-email" })
        return
      end
    else
      @user = User.new
      redirect_to root_path if params[:format] and params[:format] != "html"
    end
  end

  def block
    @user = User.find(params[:id])

    if request.post?
      if @user.is_mod_or_higher?
        flash[:notice] = "You can not ban other moderators or administrators"
        redirect_to :action => "block"
        return
      end

      Ban.create(params[:ban].merge(:banned_by => @current_user.id, :user_id => params[:id]))
      redirect_to :action => "show_blocked_users"
    else
      @ban = Ban.new(:user_id => @user.id, :duration => "1")
    end
  end

  def unblock
    params[:user].keys.each do |user_id|
      Ban.destroy_all(["user_id = ?", user_id])
    end

    redirect_to :action => "show_blocked_users"
  end

  def show_blocked_users
    #@users = User.find(:all, :select => "users.*", :joins => "JOIN bans ON bans.user_id = users.id", :conditions => ["bans.banned_by = ?", @current_user.id])
    @users = User.find(:all, :select => "users.*", :joins => "JOIN bans ON bans.user_id = users.id", :order => "expires_at ASC")
    @ip_bans = IpBans.find(:all)
  end

  if CONFIG["enable_account_email_activation"]
    def resend_confirmation
      if request.post?
        user = User.find_by_email(params[:email])

        if user.nil?
          flash[:notice] = "No account exists with that email"
          redirect_to :action => "home"
          return
        end

        if user.is_blocked_or_higher?
          flash[:notice] = "Your account is already activated"
          redirect_to :action => "home"
          return
        end

        UserMailer::deliver_confirmation_email(user)
        flash[:notice] = "Confirmation email sent"
        redirect_to :action => "home"
      end
    end

    def activate_user
      flash[:notice] = "Invalid confirmation code"

      users = User.find(:all, :conditions => ["level = ?", CONFIG["user_levels"]["Unactivated"]])
      users.each do |user|
        if User.confirmation_hash(user.name) == params["hash"]
          user.update_attribute(:level, CONFIG["starting_level"])
          flash[:notice] = "Account has been activated"
          break
        end
      end

      redirect_to :action => "home"
    end
  end

  def set_avatar
    @user = @current_user
    if params[:user_id] then
      @user = User.find(params[:user_id])
      respond_to_error("Not found", :action => "index", :status => 404) unless @user
    end

    if !@user.is_anonymous? && !@current_user.has_permission?(@user, :id)
      access_denied()
      return
    end

    if request.post?
      if @user.set_avatar(params) then
        redirect_to :action => "show", :id => @user.id
      else
        respond_to_error(@user, :action => "home")
      end
    end

    if !@user.is_anonymous? && params[:id] == @user.avatar_post_id then
      @old = params
    end

    @params = params
    @post = Post.find(params[:id])
  end

  def error
    report = params[:report]

    file = "#{Rails.root}/log/user_errors.log"
    File.open(file, "a") do |f|
      f.write(report.to_s + "\n\n\n-------------------------------------------\n\n\n")
    end

    render :json => { :success => true }
  end

  private
  def get_view_name_for_edit(param)
    case param
    when "change_email"
      :change_email
    when "change_password"
      :change_password
    else
      :edit
    end
  end
end
