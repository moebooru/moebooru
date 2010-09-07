require 'activerecord.rb'

namespace :db do
  desc "Import post history"
  task :import_post_histories => :environment do ActiveRecord::Base.import_post_tag_history end

  desc "Update histories"
  task :update_histories => :environment do ActiveRecord::Base.update_all_versioned_tables end

  desc "Import note history"
  task :import_note_histories => :environment do ActiveRecord::Base.import_note_history end
end
