class Settings::ApiController < Settings::BaseController
  before_filter :ensure_api_key

  def show
  end

  def update
    @user.set_api_key
    @user.save
    redirect_to :action => :show
  end

  private
  def ensure_api_key
    unless @user.api_key
      @user.set_api_key
      @user.save
    end
  end
end
