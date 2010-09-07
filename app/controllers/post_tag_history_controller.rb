class PostTagHistoryController < ApplicationController
  layout 'default'
  
  def index
    redirect_to :controller => "history", :action => "post"
    return
  end
end
