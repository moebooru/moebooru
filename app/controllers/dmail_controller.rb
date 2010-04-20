class DmailController < ApplicationController
  before_filter :blocked_only
  layout "default"
  
  def auto_complete_for_dmail_to_name
    @users = User.find(:all, :order => "lower(name)", :conditions => ["name ilike ? escape '\\\\'", params[:dmail][:to_name] + "%"])
    render :layout => false, :text => "<ul>" + @users.map {|x| "<li>" + x.name + "</li>"}.join("") + "</ul>"
  end
  
  def show_previous_messages
    @dmails = Dmail.find(:all, :conditions => ["(to_id = ? or from_id = ?) and parent_id = ? and id < ?", @current_user.id, @current_user.id, params[:parent_id], params[:id]], :order => "id asc")
    render :layout => false
  end
  
  def compose
    @dmail = Dmail.new
  end
  
  def create
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
    @dmails = Dmail.paginate :conditions => ["to_id = ? or from_id = ?", @current_user.id, @current_user.id], :order => "created_at desc", :per_page => 25, :page => params[:page]
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

  def mark_all_read
    if request.post?
      if params[:commit] == "Yes"
        Dmail.find(:all, :conditions => ["to_id = ? and has_seen = false", @current_user.id]).each do |dmail|
          dmail.update_attribute(:has_seen, true)
        end

        @current_user.update_attribute(:has_mail, false)
        respond_to_success("All messages marked as read", {:action => "inbox"})
      else
        redirect_to :action => "inbox"
      end
    end
  end
end
