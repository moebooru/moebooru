class Settings::BaseController < ApplicationController
  before_filter :no_anonymous
  before_filter :set_user
  layout 'default'

  private
  def set_user
    @user = @current_user
  end
end
