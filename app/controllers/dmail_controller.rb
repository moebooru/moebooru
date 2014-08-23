class DmailController < ApplicationController
  before_action :blocked_only
  layout "default"

  def preview
    render :layout => false
  end

  def show_previous_messages
    @dmails = Dmail.find(:all, :conditions => ["(to_id = ? or from_id = ?) and parent_id = ? and id < ?", @current_user.id, @current_user.id, params[:parent_id], params[:id]], :order => "id asc")
    render :layout => false
  end

  def compose
    @dmail = Dmail.new
  end

  def create
    if Dmail.where(:from_id => @current_user.id).where("created_at > ?", 1.hour.ago).count > 10
      flash[:notice] = "You can't send more than 10 dmails per hour."
      redirect_to :action => :inbox
      return
    end
    @dmail = Dmail.create(params[:dmail].merge(:from_id => @current_user.id))

    if @dmail.errors.empty?
      flash[:notice] = "Message sent to #{params[:dmail][:to_name]}"
      redirect_to :action => "inbox"
    else
      flash[:notice] = "Error: " + @dmail.errors.full_messages.join(", ")
      render :action => "compose"
    end
  end

  def inbox
    @dmails = Dmail.paginate :conditions => ["to_id = ? or from_id = ?", @current_user.id, @current_user.id], :order => "created_at desc", :per_page => 25, :page => page_number
  end

  def show
    @dmail = Dmail.find(params[:id])

    if @dmail.to_id != @current_user.id && @dmail.from_id != @current_user.id
      flash[:notice] = "Access denied"
      redirect_to :controller => "user", :action => "login"
      return
    end

    if @dmail.to_id == @current_user.id
      @dmail.mark_as_read!(@current_user)
    end
  end

  def confirm_mark_all_read
  end

  def mark_all_read
    if params[:commit] == "Yes"
      Dmail.find(:all, :conditions => ["to_id = ? and has_seen = false", @current_user.id]).each do |dmail|
        dmail.update_attribute(:has_seen, true)
      end

      @current_user.update_attribute(:has_mail, false)
      respond_to_success("All messages marked as read", { :action => "inbox" })
    else
      redirect_to :action => "inbox"
    end
  end
end
