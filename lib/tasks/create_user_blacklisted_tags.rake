require 'activerecord.rb'

namespace :user_blacklisted_tags do
  def SetDefaultBlacklistedTags
    User.transaction do
      User.find(:all, :order => "id").each do |user|
        CONFIG["default_blacklists"].each do |b|
          user.user_blacklisted_tags.create(:tags => b)
        end
      end
    end
  end

  desc 'CreateUserBlacklistedTags'
  task :add_defaults => :environment do
    SetDefaultBlacklistedTags()
  end
end
