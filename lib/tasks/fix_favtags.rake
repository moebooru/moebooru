namespace :fix do
  desc "Update favtags to new system"
  task :favtags => :environment do
    User.find(:all).each do |user|
      compiled_favtags = user.favorite_tags.map {|x| "~" + x.tag_query}.join(" ")
      user.favorite_tags.each {|x| x.destroy}
      unless compiled_favtags.blank?
        user.favorite_tags.create(:name => "General", :tag_query => compiled_favtags)
      end
    end
  end
end
