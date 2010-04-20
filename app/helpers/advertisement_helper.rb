module AdvertisementHelper
  def print_advertisement(ad_type)
		if CONFIG["can_see_ads"].call(@current_user)
	    ad = Advertisement.find(:first, :conditions => ["ad_type = ? AND status = 'active'", ad_type], :order => "random()")
	    content_tag("div", link_to(image_tag(ad.image_url, :alt => "Advertisement", :width => ad.width, :height => ad.height), :controller => "advertisement", :action => "redirect_ad", :id => ad.id), :style => "margin-bottom: 1em;")
		else
			""
		end
  end
end
