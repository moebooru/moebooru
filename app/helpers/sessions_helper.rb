module SessionsHelper
  def page_number
    unless @page_number
      @page_number = (params.delete(:page).try(:to_i) || 1).clamp(1, 1_000_000)
      params[:page] = @page_number if @page_number > 1
    end
    @page_number
  end
end
