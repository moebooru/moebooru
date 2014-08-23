class BannedController < ApplicationController
  layout "bare"
  def index
      @ban = get_ip_ban()
      if not @ban
        redirect_to :controller => "static", :action => "index"
        return
      end
  end

end
