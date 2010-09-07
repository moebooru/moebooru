class TagSubscriptionController < ApplicationController
  layout "default"
  
  def create
    if request.post?
      if @current_user.tag_subscriptions.size >= CONFIG["max_tag_subscriptions"]
        @tag_subscription = nil
      else
        @tag_subscription = TagSubscription.create(:user_id => @current_user.id, :tag_query => "")
      end
    end
  end
  
  def update
    if request.post?
      if params[:tag_subscription]
        params[:tag_subscription].each_key do |tag_subscription_id|
          tag_subscription = TagSubscription.find(tag_subscription_id)
          if tag_subscription.user_id == @current_user.id
            tag_subscription.update_attributes(params[:tag_subscription][tag_subscription_id])
          end
        end
      end
      
      flash[:notice] = "Tag subscriptions updated"
      redirect_to :controller => "user", :action => "edit"
    end
  end
  
  def index
    @tag_subscriptions = @current_user.tag_subscriptions
  end
  
  def destroy
    if request.post?
      @tag_subscription = TagSubscription.find(params[:id])

      if @current_user.has_permission?(@tag_subscription)
        @tag_subscription.destroy
      end
    end
  end
end
