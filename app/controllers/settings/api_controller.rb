class Settings::ApiController < Settings::BaseController
  before_filter :ensure_api_key

  def show
  end

  private
  def ensure_api_key
    unless @user.api_key
      @user.set_api_key
      @user.save
    end
  end
end
