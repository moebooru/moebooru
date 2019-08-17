class TagSubscriptionController < ApplicationController
  layout "default"
  before_action :member_only, :except => :index
  before_action :no_anonymous

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
        params[:tag_subscription].each do |id, params|
          tag_subscription = TagSubscription.find(id)
          if tag_subscription.user_id == @current_user.id
            tag_subscription.update(tag_subscription_params(params))
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

  private

  def tag_subscription_params(p)
    p.permit(:name, :tag_query, :is_visible_on_profile)
  end
end
