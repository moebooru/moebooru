module SessionsHelper
  def page_number
    if not @page_number
      @page_number = params[:page].to_i
      if @page_number < 1
        @page_number = 1
      end
    end
    @page_number
  end
end
