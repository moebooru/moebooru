namespace :fix do
  desc "Update favtags to new system"
  task :favtags => :environment do
    ActiveRecord::Base.connection.execute("UPDATE tag_subscriptions SET tag_query = replace(tag_query, '~', '')")

    user_ids = ActiveRecord::Base.select_all_sql("SELECT DISTINCT user_id FROM tag_subscriptions")
    user_ids.each do |u|
      id = u["user_id"].to_i
      user = User.find_by_id(id)
      s = user.tag_subscriptions.map(&:tag_query)
      user.tag_subscriptions.delete_all
      user.tag_subscriptions.create!(:name => "General", :tag_query => s.join(" "))
    end
  end
end
