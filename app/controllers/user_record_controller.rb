class UserRecordController < ApplicationController
  layout "default"
  before_action :privileged_only, :only => [:create, :destroy]

  def index
    @user_records = UserRecord.order :created_at => :desc
    if params[:user_id]
      @user = User.find_by(:id => params[:user_id])
      @user_records = @user_records.where :user_id => params[:user_id]
    end

    @user_records = @user_records.paginate :per_page => 20, :page => page_number
  end

  def create
    @user = User.find(params[:user_id])

    if request.post?
      if @user.id == @current_user.id
        flash[:notice] = "You cannot create a record for yourself"
      else
        @user_record = UserRecord.create(user_record_params.merge(:user_id => params[:user_id], :reported_by => @current_user.id))
        flash[:notice] = "Record updated"
      end
      redirect_to :action => "index", :user_id => @user.id
    end
  end

  def destroy
    @user_record = UserRecord.find(params[:id])
    if @current_user.is_mod_or_higher? || @current_user.id == @user_record.reported_by
      UserRecord.destroy(params[:id])

      respond_to_success("Record updated", :action => "index", :user_id => params[:id])
    else
      access_denied
    end
  end

  private

  def user_record_params
    params.require(:user_record).permit(:is_positive, :body)
  end
end
