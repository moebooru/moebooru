class FavoriteTagController < ApplicationController
  layout "default"
  
  def create
    if request.post?
      if @current_user.favorite_tags.size >= CONFIG["favorite_tag_limit"]
        @favtag = nil
      else
        @favtag = FavoriteTag.create(:user_id => @current_user.id, :tag_query => "")
      end
    end
  end
  
  def update
    if request.post? && params[:favtag]
      params[:favtag].each_key do |favtag_id|
        favtag = FavoriteTag.find(favtag_id)
        if favtag.user_id == @current_user.id
          favtag.update_attributes(params[:favtag][favtag_id])
        end
      end
      
      flash[:notice] = "Favorite tags updated"
      redirect_to :controller => "user", :action => "edit"
    end
  end
  
  def index
    @favtags = @current_user.favorite_tags
  end
  
  def destroy
    if request.post?
      @favtag = FavoriteTag.find(params[:id])

      if @current_user.has_permission?(@favtag)
        @favtag.destroy
      end
    end
  end
end
