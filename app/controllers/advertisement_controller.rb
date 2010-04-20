class AdvertisementController < ApplicationController
  layout "bare"
	before_filter :admin_only, :only => [:reset_stats]

	def redirect_ad
		ad = Advertisement.find(params[:id])
	  ad.increment!(:hit_count)
		redirect_to ad.referral_url
	end
	
	def show_stats
		@ads = Advertisement.find(:all, :order => "id")
		render :layout => "default"
	end
	
	def reset_stats
		Advertisement.update_all("hit_count = 0")
		redirect_to :action => "show_stats"
	end
end
