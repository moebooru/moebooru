module SessionsHelper
  def page_number
    if !@page_number
      @page_number = params[:page].blank? ? 1 : params[:page]
    else
      @page_number
    end
  end
end
