class FavoriteController < ApplicationController
  layout "default"
  helper :post

  def list_users
    @post = Post.find(params[:id])
    respond_to do |fmt|
      fmt.json do
        render :json => { :favorited_users => @post.favorited_by.map(&:name).join(",") }.to_json
      end
    end
  end

  protected

  def favorited_users_for_post(post)
    post.favorited_by.map(&:name).uniq.join(",")
  end
end
