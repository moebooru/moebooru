namespace :job do
  desc 'Retart the job task processor'
  task :restart => :environment do
    `ruby #{RAILS_ROOT}/app/daemons/job_task_processor_ctl.rb restart`
  end
end
