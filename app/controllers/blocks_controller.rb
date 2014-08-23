class CanNotBanSelf < Exception
end

class BlocksController < ApplicationController
  before_action :mod_only, :only => [:block_ip, :unblock_ip]

  def block_ip
    begin
      IpBans.transaction do
        ban = IpBans.create(params[:ban].merge(:banned_by => @current_user.id))
        raise CanNotBanSelf if IpBans.where(:id => ban.id).where("? <<= ip_addr", request.remote_ip).exists?
      end
    rescue CanNotBanSelf
      flash[:notice] = "You can not ban yourself"
    end
    redirect_to :controller => "user", :action => "show_blocked_users"
  end

  def unblock_ip
    params[:ip_ban].keys.each do |ban_id|
      IpBans.destroy_all(["id = ?", ban_id])
    end

    redirect_to :controller => "user", :action => "show_blocked_users"
  end
end
