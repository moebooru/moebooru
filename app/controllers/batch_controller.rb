require 'extract_urls'

class BatchController < ApplicationController
  layout 'default'
  before_filter :contributor_only, :only => [:index, :create, :enqueue, :update]

  def index
    set_title "Batch queue"

    if @current_user.is_mod_or_higher? and params[:user_id] == "all" then
      user_id = nil
    elsif @current_user.is_mod_or_higher? and params[:user_id] then
      user_id = params[:user_id]
    else
      user_id = @current_user.id
    end

    p = {:per_page => 25, :order => "created_at ASC, id ASC", :page => page_number}
    conds = []
    cond_params = []
    if not user_id.nil? then
      conds.push("user_id = ?")
      cond_params.push(user_id)
    end
    # conds.push("batch_uploads.status = 'deleted'")
    p[:conditions] = [conds.join(" AND "), *cond_params]
    @items = BatchUpload.paginate(p)
  end

  def update
    conds = []
    cond_params = []

    if @current_user.is_mod_or_higher? and params[:user_id] == "all" then
    elsif @current_user.is_mod_or_higher? and params[:user_id] then
      conds.push("user_id = ?")
      cond_params.push(params[:user_id])
    else
      conds.push("user_id = ?")
      cond_params.push(@current_user.id)
    end

    # Never touch active files.  This can race with the uploader.
    conds.push("not active")

    count = 0

    if params[:do] == "pause" then
      conds.push("status = 'pending'")
      BatchUpload.find(:all, :conditions => [conds.join(" AND "), *cond_params]).each { |item|
        item.update_attributes(:status => "paused")
        count += 1
      }
      flash[:notice] = "Paused %i uploads." % count
    elsif params[:do] == "unpause" then
      conds.push("status = 'paused'")
      BatchUpload.find(:all, :conditions => [conds.join(" AND "), *cond_params]).each { |item|
        item.update_attributes(:status => "pending")
        count += 1
      }
      flash[:notice] = "Resumed %i uploads." % count
    elsif params[:do] == "retry" then
      conds.push("status = 'error'")

      BatchUpload.find(:all, :conditions => [conds.join(" AND "), *cond_params]).each { |item|
        item.update_attributes(:status => "pending")
        count += 1
      }

      flash[:notice] = "Retrying %i uploads." % count
    elsif params[:do] == "clear_finished" then
      conds.push("(status = 'finished' or status = 'error')")
      BatchUpload.find(:all, :conditions => [conds.join(" AND "), *cond_params]).each { |item|
        item.destroy
        count += 1
      }

      flash[:notice] = "Cleared %i finished uploads." % count
    elsif params[:do] == "abort_all" then
      conds.push("(status = 'pending' or status = 'paused')")
      BatchUpload.find(:all, :conditions => [conds.join(" AND "), *cond_params]).each { |item|
        item.destroy
        count += 1
      }

      flash[:notice] = "Cancelled %i uploads." % count
    end

    redirect_to :action => "index"
    return
  end

  def create
    set_title "Queue uploads"

    filter = {}
    if @current_user.is_mod_or_higher? and params[:user_id] == "all" then
    elsif @current_user.is_mod_or_higher? and params[:user_id] then
      filter[:user_id] = params[:user_id]
    else
      filter[:user_id] = @current_user.id
    end

    if params[:url] then
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
    count = 0
    for url in params[:files] do
      count += 1
      tags = params[:post][:tags] || ""
      tags = tags.split(/ /)
      if params[:post][:rating] then
        # Add this to the beginning, so any rating: metatags in the tags will
        # override it.
        tags = ["rating:" + params[:post][:rating]] + tags
      end
      tags.push("hold")
      tags = tags.uniq.join(" ")

      b = BatchUpload.find_or_initialize_by_url_and_user_id(:user_id => @current_user.id, :url => url)
      b.tags = tags
      b.ip = request.remote_ip
      b.save!
    end

    flash[:notice] = "Queued %i files" % count
    redirect_to :action => "index"
  end
end
