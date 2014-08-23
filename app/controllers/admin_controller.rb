class AdminController < ApplicationController
  layout "default"
  before_action :admin_only

  def index
  end

  def edit_user
    if request.post?
      @user = User.find_by_name(params[:user][:name])
      if @user.nil?
        flash[:notice] = "User not found"
        redirect_to :action => "edit_user"
        return
      end
      @user.level = params[:user][:level]

      if @user.save
        flash[:notice] = "User updated"
        redirect_to :action => "edit_user"
      else
        render_error(@user)
      end
    end
  end

  def reset_password
    if request.post?
      @user = User.find_by_name(params[:user][:name])

      if @user
        new_password = @user.reset_password
        flash[:notice] = "Password reset to #{new_password}"

        unless @user.email.blank?
          begin
            UserMailer.new_password(@user, new_password).deliver
          rescue Net::SMTPSyntaxError, Net::SMTPFatalError
            respond_to_success("Specified user's email address was invalid",
              { :action => :reset_password }, :api => { :result => "invalid-email" })
            return
          end
        end
      else
        flash[:notice] = "That account does not exist"
        redirect_to :action => "reset_password"
      end
    else
      @user = User.new
    end
  end

  def cache_stats
    keys = []
    [0, 20, 30, 35, 40, 50].each do |level|
      keys << "stats/count/level=#{level}"

      [0, 1, 2, 3, 4, 5].each do |tag_count|
        keys << "stats/tags/level=#{level}&tags=#{tag_count}"
      end

      keys << "stats/page/level=#{level}&page=0-10"
      keys << "stats/page/level=#{level}&page=10-20"
      keys << "stats/page/level=#{level}&page=20+"
    end

    @post_stats = keys.inject({}) { |h, k| h[k] = Rails.cache.read(k); h }
  end

  def reset_post_stats
    keys = []
    [0, 20, 30, 35, 40].each do |level|
      keys << "stats/count/level=#{level}"

      [0, 1, 2, 3, 4, 5].each do |tag_count|
        keys << "stats/tags/level=#{level}&tags=#{tag_count}"
      end

      keys << "stats/page/level=#{level}&page=0-10"
      keys << "stats/page/level=#{level}&page=10-20"
      keys << "stats/page/level=#{level}&page=20+"
    end

    keys.each do |key|
      Rails.cache.write(key, 0)
    end

    redirect_to :action => "cache_stats"
  end
end
