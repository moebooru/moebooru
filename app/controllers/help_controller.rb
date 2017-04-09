class HelpController < ApplicationController
  layout "default"

  def show
    render "/help/#{params[:page].presence || "index"}"
  rescue ActionView::MissingTemplate
    head :not_found
  end
end
