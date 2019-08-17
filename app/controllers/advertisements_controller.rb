class AdvertisementsController < ApplicationController
  layout "default"
  before_action :admin_only, :except => :redirect

  def index
    @ads = Advertisement.paginate(:page => page_number, :per_page => 100)
  end

  def show
    @ad = Advertisement.find(params[:id])
  end

  def new
    @ad = Advertisement.new
  end

  def create
    @ad = Advertisement.new(params[:advertisement])
    if @ad.save
      flash[:success] = "Advertisement added"
      redirect_to @ad
    else
      render :new
    end
  end

  def edit
    @ad = Advertisement.find(params[:id])
  end

  def update
    @ad = Advertisement.find(params[:id])
    if @ad.update(params[:advertisement])
      flash[:success] = "Advertisement updated"
      redirect_to @ad
    else
      render :edit
    end
  end

  def update_multiple
    if params[:advertisement_ids]
      ids = params[:advertisement_ids].map(&:to_i)
    else
      return redirect_to advertisements_path, :notice => "No advertisement selected"
    end
    if params[:do_delete]
      Advertisement.destroy_all :id => ids
    elsif params[:do_reset_hit_count]
      Advertisement.reset_hit_count ids
    end
    flash[:success] = "Advertisements updated"
    redirect_to advertisements_path
  end

  def destroy
    @ad = Advertisement.find(params[:id])
    @ad.destroy
    flash[:notice] = "Deleted advertisement #{@ad.id}"
    redirect_to advertisements_path
  end

  def redirect
    ad = Advertisement.find(params[:id])
    ad.increment!(:hit_count)
    redirect_to ad.referral_url
  end
end
