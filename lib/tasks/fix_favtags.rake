namespace :fix do
  desc "Update favtags to new system"
  task :favtags => :environment do
    User.find(:all, :conditions => ["id = 1 AND level >= ?", CONFIG["user_levels"]["Privileged"]]).each do |user|
      compiled_favtags = user.favorite_tags.map {|x| "~" + x.tag_query}.join(" ")
      user.favorite_tags.each {|x| x.destroy}
      user.favorite_tags.create(:name => "General", :tag_query => compiled_favtags)
    end
  end
end
