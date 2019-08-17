require "extract_urls"

class BatchController < ApplicationController
  layout "default"
  before_action :contributor_only, :only => [:index, :create, :enqueue, :update]

  def index
    if @current_user.is_mod_or_higher? && params[:user_id] == "all"
      user_id = nil
    elsif @current_user.is_mod_or_higher? && params[:user_id]
      user_id = params[:user_id]
    else
      user_id = @current_user.id
    end

    @items = BatchUpload.order(:created_at => :asc, :id => :asc)
    @items = @items.where(:user_id => user_id) if user_id.present?
    @items = @items.paginate(:per_page => 25, :page => page_number)
  end

  def update
    conds = []
    cond_params = []

    if @current_user.is_mod_or_higher? && params[:user_id] == "all"
    elsif @current_user.is_mod_or_higher? && params[:user_id]
      conds.push("user_id = ?")
      cond_params.push(params[:user_id])
    else
      conds.push("user_id = ?")
      cond_params.push(@current_user.id)
    end

    # Never touch active files.  This can race with the uploader.
    conds.push("not active")

    count = 0

    if params[:do] == "pause"
      conds.push("status = 'pending'")
      BatchUpload.where(conds.join(" AND "), *cond_params).find_each do |item|
        item.update(:status => "paused")
        count += 1
      end
      flash[:notice] = "Paused %i uploads." % count
    elsif params[:do] == "unpause"
      conds.push("status = 'paused'")
      BatchUpload.where(conds.join(" AND "), *cond_params).find_each do |item|
        item.update(:status => "pending")
        count += 1
      end
      flash[:notice] = "Resumed %i uploads." % count
    elsif params[:do] == "retry"
      conds.push("status = 'error'")

      BatchUpload.where(conds.join(" AND "), *cond_params).find_each do |item|
        item.update(:status => "pending")
        count += 1
      end

      flash[:notice] = "Retrying %i uploads." % count
    elsif params[:do] == "clear_finished"
      conds.push("(status = 'finished' or status = 'error')")
      BatchUpload.where(conds.join(" AND "), *cond_params).find_each do |item|
        item.destroy
        count += 1
      end

      flash[:notice] = "Cleared %i finished uploads." % count
    elsif params[:do] == "abort_all"
      conds.push("(status = 'pending' or status = 'paused')")
      BatchUpload.where(conds.join(" AND "), *cond_params).find_each do |item|
        item.destroy
        count += 1
      end

      flash[:notice] = "Cancelled %i uploads." % count
    end

    redirect_to :action => "index"
  end

  def create
    filter = {}
    if @current_user.is_mod_or_higher? && params[:user_id] == "all"
    elsif @current_user.is_mod_or_higher? && params[:user_id]
      filter[:user_id] = params[:user_id]
    else
      filter[:user_id] = @current_user.id
    end

    if params[:url].present?
      @source = params[:url]

      text = ""
      Danbooru.http_get_streaming(@source) do |response|
        response.read_body do |block|
          text += block
        end
      end

      @urls = ExtractUrls.extract_image_urls(@source, text)
    end
  end

  def enqueue
    # Ignore duplicate URLs across users, but duplicate URLs for the same user aren't allowed.
    # If that happens, just update the tags.
    params[:files].each do |url|
      tags = params[:post][:tags] || ""
      tags = tags.split(/ /)
      if params[:post][:rating]
        # Add this to the beginning, so any rating: metatags in the tags will
        # override it.
        tags = ["rating:" + params[:post][:rating]] + tags
      end
      tags.push("hold")
      tags = tags.uniq.join(" ")

      b = BatchUpload.find_or_initialize_by(:user_id => @current_user.id, :url => url)
      b.tags = tags
      b.ip = request.remote_ip
      b.save!
    end

    flash[:notice] = "Queued %i files" % params[:files].count
    redirect_to :action => "index"
  end
end
