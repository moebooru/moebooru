namespace :job do
  desc 'Retart the job task processor'
  task :restart => :environment do
    `ruby #{Rails.root}/app/daemons/job_task_processor_ctl.rb restart`
  end

  desc 'Start the job task processor'
  task :start => :environment do
    `ruby #{Rails.root}/app/daemons/job_task_processor_ctl.rb start`
  end

  desc 'Stop the job task processor'
  task :stop => :environment do
    `ruby #{Rails.root}/app/daemons/job_task_processor_ctl.rb stop`
  end
end
