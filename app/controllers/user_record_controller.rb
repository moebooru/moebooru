class UserRecordController < ApplicationController
  layout "default"
  before_filter :privileged_only, :only => [:create, :destroy]
  
  def index
    if params[:user_id]
      @user = User.find(params[:user_id])
      @user_records = UserRecord.paginate :per_page => 20, :order => "created_at desc", :conditions => ["user_id = ?", params[:user_id]], :page => params[:page]
    else
      @user_records = UserRecord.paginate :per_page => 20, :order => "created_at desc", :page => params[:page]
    end
  end
  
  def create
    @user = User.find(params[:user_id])

    if request.post?
      if @user.id == @current_user.id
        flash[:notice] = "You cannot create a record for yourself"
      else
        @user_record = UserRecord.create(params[:user_record].merge(:user_id => params[:user_id], :reported_by => @current_user.id))
        flash[:notice] = "Record updated"
      end
      redirect_to :action => "index", :user_id => @user.id
    end
  end
  
  def destroy
    if request.post?
      @user_record = UserRecord.find(params[:id])
      if @current_user.is_mod_or_higher? || @current_user.id == @user_record.reported_by
        UserRecord.destroy(params[:id])
      
        respond_to_success("Record updated", :action => "index", :user_id => params[:id])
      else
        access_denied()
      end
    end
  end
end
