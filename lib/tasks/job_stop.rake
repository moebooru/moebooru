namespace :job do
  desc 'Stop the job task processor'
  task :stop => :environment do
    `ruby #{RAILS_ROOT}/app/daemons/job_task_processor_ctl.rb stop`
  end
end
