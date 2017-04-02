class HelpController < ApplicationController
  layout "default"

  def show
    render "/help/#{params[:page].presence || "index"}"
  end
end
