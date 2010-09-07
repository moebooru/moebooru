namespace :fix do
  desc "Update favtags to new system"
  task :favtags => :environment do
    User.find(:all).each do |user|
      ActiveRecord::Base.connection.execute("UPDATE tag_subscriptions SET tag_query = replace(tag_query, '~', '')")
    end
  end
end
