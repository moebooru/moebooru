class PostTagHistoryController < ApplicationController
  def index
    redirect_to :controller => "post", :action => "index"
  end
end
