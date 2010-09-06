class FavoriteController < ApplicationController
  layout "default"
  before_filter :blocked_only, :only => [:create, :destroy]
  verify :method => :post, :only => [:create, :destroy]
  helper :post
  
  def list_users
    @post = Post.find(params[:id])
    respond_to do |fmt|
      fmt.json do
        render :json => {:favorited_users => @post.favorited_by.map(&:name).join(",")}.to_json
        render :xml => {:favorited_users => @post.favorited_by.map(&:name)}.to_xml
      end
    end
  end
  
protected
  def favorited_users_for_post(post)
    post.favorited_by.map {|x| x.name}.uniq.join(",")
  end
end
