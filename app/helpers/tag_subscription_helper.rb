module TagSubscriptionHelper
  def tag_subscription_listing(user)
    html = []
    user.tag_subscriptions.each do |tag_subscription|
      html << '<span class="group"><strong>' + link_to(h(tag_subscription.name), :controller => "post", :action => "index", :tags => "sub:#{user.name}:#{tag_subscription.name}") + '</strong>: '
      tags = tag_subscription.tag_query.scan(/\S+/).sort
      group = []
      tags.each do |tag|
        group << link_to(h(tag), :controller => "post", :action => "index", :tags => tag)
      end
      html[-1] << group.join(" ") + '</span>'
    end
    html.join(" ")
  end
end
