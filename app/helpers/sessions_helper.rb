module SessionsHelper
  def page_number
    unless @page_number
      if params[:page]
        params[:page] = params[:page].to_i
        params.delete(:page) if params[:page] <= 1
      end
      @page_number = params[:page] || 1
    end
    @page_number
  end
end
