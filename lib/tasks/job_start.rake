namespace :job do
  desc 'Start the job task processor'
  task :start => :environment do
    `ruby #{RAILS_ROOT}/app/daemons/job_task_processor_ctl.rb start`
  end
end
