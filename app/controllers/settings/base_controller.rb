class Settings::BaseController < ApplicationController
  before_action :no_anonymous
  before_action :set_user
  layout "settings"

  private
  def set_user
    @user = @current_user
  end
end
