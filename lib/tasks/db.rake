require 'activerecord.rb'

namespace :db do
  desc "Import histories"
  task :import_histories => :environment do ActiveRecord::Base.import_post_tag_history end

  desc "Update histories"
  task :update_histories => :environment do ActiveRecord::Base.update_all_versioned_tables end
end
