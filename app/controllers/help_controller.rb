class HelpController < ApplicationController
  layout "default"

  def show
    page = params[:page].presence

    if page.present?
      sanitized_page = page.gsub(/[^a-z0-9_]/, '')

      return head(:not_found) if sanitized_page != page
    else
      page = 'index'
    end

    render "/help/#{page}"
  rescue ActionView::MissingTemplate
    head :not_found
  end
end
