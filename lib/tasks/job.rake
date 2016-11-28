require "rbconfig"

namespace :job do
  desc "Start the job task processor"
  task :start => :environment do
    JobTask.execute_all
  end
end
